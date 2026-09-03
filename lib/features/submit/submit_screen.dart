import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

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

  static const _aspectTolerance = 0.08;
  static const _jpegQuality = 82;
  static const _maxPayloadBytes = 4 * 1024 * 1024;

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

  Future<File> _compressSquare(File file, {img.Image? decoded}) async {
    final bytes = decoded == null ? await file.readAsBytes() : null;
    final image = decoded ?? img.decodeImage(bytes!);
    if (image == null) return file;

    final side = math.min(image.width, image.height);
    final sx = ((image.width - side) / 2).floor();
    final sy = ((image.height - side) / 2).floor();
    final square = img.copyCrop(image, x: sx, y: sy, width: side, height: side);
    final size = AppConstants.instance.imageOutputSize;
    final resized = img.copyResize(
      square,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );

    final out = File(
      '${Directory.systemTemp.path}/pattern_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(resized, quality: _jpegQuality));
    return out;
  }

  bool _isNearlySquare(img.Image image) {
    if (image.width == 0 || image.height == 0) return false;
    return (image.width / image.height - 1).abs() <= _aspectTolerance;
  }

  Future<File?> _cropSquare(String path) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: _jpegQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: AppColors.accent,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.accent,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          cropStyle: CropStyle.rectangle,
          showCropGrid: true,
          hideBottomControls: false,
          cropFrameStrokeWidth: 3,
          cropGridStrokeWidth: 1,
        ),
        IOSUiSettings(
          title: 'Crop photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          rotateButtonsHidden: true,
          rotateClockwiseButtonHidden: true,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          minimumAspectRatio: 1,
        ),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
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
      final prepared = <File>[];
      for (final xfile in picked) {
        if (_images.length + prepared.length >= max) break;
        final source = File(xfile.path);
        final bytes = await source.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('We couldn’t read one of those images.')),
            );
          }
          continue;
        }

        File? working = source;
        if (!_isNearlySquare(decoded)) {
          working = await _cropSquare(source.path);
          if (working == null) continue;
        }

        final compressed = await _compressSquare(working);
        prepared.add(compressed);
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

  Future<void> _submit() async {
    var payloadBytes = utf8.encode(_title.text).length + utf8.encode(_url.text).length + 64;
    for (final image in _images) {
      payloadBytes += await image.length();
    }
    if (_pdf != null) payloadBytes += await _pdf!.length();
    if (payloadBytes > _maxPayloadBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Those files are too large to upload together. Remove a photo or PDF.'),
          ),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final form = FormData.fromMap({
        'title': _title.text.trim(),
        'patternUrl': _url.text.trim(),
        'isFree': _isFree.toString(),
        'categorySlug': _category,
        'images': await Future.wait(
          _images.map((f) async => MultipartFile.fromFile(f.path, filename: f.path.split('/').last)),
        ),
        if (_pdf != null) 'pdf': await MultipartFile.fromFile(_pdf!.path, filename: _pdf!.path.split('/').last),
      });
      await ref.read(apiClientProvider).postMultipart('/patterns', form);
      ref.invalidate(myPatternsProvider);
      ref.invalidate(patternsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern submitted!')));
        context.go('/');
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
          'Photos are compressed to about ${AppConstants.instance.imageOutputSize}×${AppConstants.instance.imageOutputSize}. Non-square photos open a crop first.',
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
                    child: Image.file(_images[i], width: 72, height: 72, fit: BoxFit.cover),
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
