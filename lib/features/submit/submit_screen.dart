import 'dart:io';

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
  bool _isFree = true;
  final List<File> _images = [];
  File? _pdf;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _category = AppConstants.instance.defaultRankBoardCategory;
  }

  Future<File?> _resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return file;
    final size = AppConstants.instance.imageOutputSize;
    final resized = img.copyResize(decoded, width: size, height: size, interpolation: img.Interpolation.linear);
    final out = File('${file.path}_resized.jpg');
    await out.writeAsBytes(img.encodeJpg(resized, quality: 90));
    return out;
  }

  Future<void> _pickImage() async {
    final max = AppConstants.instance.maxPatternImages;
    if (_images.length >= max) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You can add up to $max photos.')));
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop photo', toolbarColor: AppColors.accent, toolbarWidgetColor: Colors.white),
        IOSUiSettings(title: 'Crop photo'),
      ],
    );
    if (cropped == null) return;
    final resized = await _resizeImage(File(cropped.path));
    if (resized != null) setState(() => _images.add(resized));
  }

  Future<void> _pickPdf() async {
    if (!_isFree) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = result?.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (file.lengthSync() > AppConstants.instance.maxPdfBytes) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF must be 20 MB or smaller.')));
      return;
    }
    setState(() => _pdf = file);
  }

  Future<void> _submit() async {
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
              FilledButton(onPressed: () => context.go('/settings'), child: const Text('Go to settings')),
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
              FilledButton(onPressed: () => context.go('/settings'), child: const Text('Go to settings')),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final image in _images)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image, width: 72, height: 72, fit: BoxFit.cover),
              ),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_a_photo),
              label: Text('Add photo (${_images.length}/${AppConstants.instance.maxPatternImages})'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _uploading || _images.isEmpty ? null : _submit,
          child: Text(_uploading ? 'Uploading…' : 'Submit pattern'),
        ),
      ],
    );
  }
}
