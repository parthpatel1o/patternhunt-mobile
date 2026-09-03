import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';

class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({super.key});

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  late String _category;
  bool _isFree = false;
  final List<File> _images = [];
  File? _pdf;
  bool _uploading = false;
  bool _preparing = false;

  static const _jpegQuality = 82;

  @override
  void initState() {
    super.initState();
    _category = AppConstants.instance.defaultRankBoardCategory;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  /// Fit the photo inside a fixed square with white letterboxing (no cropping).
  Future<File> _fitInSquare(File file, {img.Image? decoded}) async {
    final bytes = decoded == null ? await file.readAsBytes() : null;
    final image = decoded ?? img.decodeImage(bytes!);
    if (image == null) return file;

    final size = AppConstants.instance.imageOutputSize;
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final scale = math.min(size / image.width, size / image.height);
    final drawWidth = math.max(1, (image.width * scale).round());
    final drawHeight = math.max(1, (image.height * scale).round());
    final resized = img.copyResize(
      image,
      width: drawWidth,
      height: drawHeight,
      interpolation: img.Interpolation.linear,
    );
    final dx = ((size - drawWidth) / 2).round();
    final dy = ((size - drawHeight) / 2).round();
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

    final out = File(
      '${Directory.systemTemp.path}/pattern_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(canvas, quality: _jpegQuality));
    return out;
  }

  Future<void> _pickImages() async {
    final max = AppConstants.instance.maxPatternImages;
    final remaining = max - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You can add up to $max photos.')));
      return;
    }

    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final single = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      picked = single == null ? const [] : [single];
    } else {
      picked = await picker.pickMultiImage(imageQuality: 95, limit: remaining);
    }
    if (picked.isEmpty || !mounted) return;

    setState(() => _preparing = true);
    try {
      final limited = picked.take(remaining).toList();
      final results = await Future.wait(limited.map((xfile) async {
        final source = File(xfile.path);
        final bytes = await source.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) return null;
        return _fitInSquare(source, decoded: decoded);
      }));

      final prepared = results.whereType<File>().toList();
      if (prepared.length < limited.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We couldn’t read one of those images.')),
        );
      }
      if (!mounted) return;
      setState(() => _images.addAll(prepared));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _pickPdf() async {
    if (!_isFree) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = result?.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (file.lengthSync() > AppConstants.instance.maxPdfBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF must be 20 MB or smaller.')));
      }
      return;
    }
    setState(() => _pdf = file);
  }

  Future<void> _putToSignedUrl(String url, File file, String contentType) async {
    final bytes = await file.readAsBytes();
    final response = await Dio().put<List<int>>(
      url,
      data: bytes,
      options: Options(
        headers: {'Content-Type': contentType},
        contentType: contentType,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode == null || response.statusCode! >= 300) {
      throw ApiException('Upload failed (${response.statusCode ?? 'unknown'}).');
    }
  }

  Future<void> _submit() async {
    if (_images.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final api = ref.read(apiClientProvider);
      final urls = await api.post('/patterns/upload-urls', data: {
        'imageCount': _images.length,
        'hasPdf': _pdf != null,
      });

      final imageSlots = (urls['images'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final pdfSlot = urls['pdf'] as Map<String, dynamic>?;
      if (imageSlots.length != _images.length) {
        throw ApiException('Could not prepare image uploads.');
      }
      if (_pdf != null && pdfSlot == null) {
        throw ApiException('Could not prepare PDF upload.');
      }

      await Future.wait([
        for (var i = 0; i < imageSlots.length; i++)
          _putToSignedUrl(
            imageSlots[i]['uploadUrl'] as String,
            _images[i],
            imageSlots[i]['contentType'] as String? ?? 'image/jpeg',
          ),
        if (_pdf != null && pdfSlot != null)
          _putToSignedUrl(
            pdfSlot['uploadUrl'] as String,
            _pdf!,
            pdfSlot['contentType'] as String? ?? 'application/pdf',
          ),
      ]);

      await api.post('/patterns', data: {
        'patternId': urls['patternId'],
        'title': _title.text.trim(),
        'patternUrl': _url.text.trim(),
        'isFree': _isFree,
        'categorySlug': _category,
        'imageKeys': imageSlots.map((s) => s['key']).toList(),
        'pdfKey': pdfSlot?['key'],
      });

      ref.invalidate(myPatternsProvider);
      ref.invalidate(patternsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern submitted!')));
        context.go('/');
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile != null && !profile.isPatternDesigner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Turn on pattern designer in Settings before submitting.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.go('/profile'), child: const Text('Go to profile')),
            ],
          ),
        ),
      );
    }
    if (profile != null && (profile.displayName == null || profile.displayName!.trim().isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add your designer name in Settings before submitting.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.go('/profile'), child: const Text('Go to profile')),
            ],
          ),
        ),
      );
    }

    final categories = AppConstants.instance.categories;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 12),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'Pattern URL')),
        const SizedBox(height: 12),
        DropdownMenu<String>(
          initialSelection: _category,
          label: const Text('Category'),
          dropdownMenuEntries: [
            for (final c in categories) DropdownMenuEntry(value: c.slug, label: c.name),
          ],
          onSelected: (v) => setState(() => _category = v ?? _category),
        ),
        SwitchListTile(
          title: const Text('Free pattern'),
          value: _isFree,
          onChanged: (v) => setState(() {
            _isFree = v;
            if (!v) _pdf = null;
          }),
        ),
        if (_isFree) ...[
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(_pdf == null ? 'Add PDF (optional)' : _pdf!.path.split('/').last),
            trailing: _pdf != null ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _pdf = null)) : null,
            onTap: _pickPdf,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Choose one or more photos. Square photos preferred.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _images.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: Colors.white,
                      child: Image.file(_images[i], width: 72, height: 72, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _images.removeAt(i)),
                    ),
                  ),
                ],
              ),
            OutlinedButton.icon(
              onPressed: _preparing || _uploading ? null : _pickImages,
              icon: _preparing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo),
              label: Text(
                _preparing
                    ? 'Preparing…'
                    : 'Add photos (${_images.length}/${AppConstants.instance.maxPatternImages})',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _uploading || _preparing || _images.isEmpty ? null : _submit,
          child: Text(_uploading ? 'Uploading…' : 'Submit pattern'),
        ),
      ],
    );
  }
}
