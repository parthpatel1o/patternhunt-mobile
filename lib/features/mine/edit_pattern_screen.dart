import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/images/square_crop.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class _ExistingPhoto {
  _ExistingPhoto({required this.key, required this.url});
  final String key;
  final String url;
}

class EditPatternScreen extends ConsumerStatefulWidget {
  const EditPatternScreen({super.key, required this.patternId});

  final String patternId;

  @override
  ConsumerState<EditPatternScreen> createState() => _EditPatternScreenState();
}

class _EditPatternScreenState extends ConsumerState<EditPatternScreen> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _preparing = false;
  bool _isFree = false;
  bool _hasPdf = false;
  String? _createdAt;
  String? _error;
  final List<_ExistingPhoto> _existing = [];
  final List<File> _newFiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getData<Map<String, dynamic>>(
        '/me/patterns/${widget.patternId}',
        map: (json) => (json as Map<String, dynamic>?) ?? {},
      );
      if (!mounted) return;
      setState(() {
        _title.text = (data['title'] as String?) ?? '';
        _url.text = (data['patternUrl'] as String?) ?? '';
        _isFree = data['isFree'] == true;
        _hasPdf = data['hasPdf'] == true;
        _createdAt = data['createdAt'] as String?;
        _existing
          ..clear()
          ..addAll(
            ((data['images'] as List<dynamic>?) ?? []).map((item) {
              final map = item as Map<String, dynamic>;
              return _ExistingPhoto(
                key: map['key'] as String,
                url: map['url'] as String,
              );
            }),
          );
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this pattern.';
      });
    }
  }

  int get _photoCount => _existing.length + _newFiles.length;

  Future<File> _compress(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;
    final maxSide = AppConstants.instance.imageOutputSize;
    final longest = math.max(image.width, image.height);
    final img.Image output;
    if (longest <= maxSide) {
      output = image;
    } else {
      final scale = maxSide / longest;
      output = img.copyResize(
        image,
        width: math.max(1, (image.width * scale).round()),
        height: math.max(1, (image.height * scale).round()),
        interpolation: img.Interpolation.linear,
      );
    }
    final out = File(
      '${Directory.systemTemp.path}/edit_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(output, quality: 82));
    return out;
  }

  Future<void> _addPhotos() async {
    final max = AppConstants.instance.maxPatternImages;
    final remaining = max - _photoCount;
    if (remaining <= 0) return;

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
      for (final xfile in picked.take(remaining)) {
        prepared.add(await _compress(File(xfile.path)));
      }
      if (!mounted) return;
      setState(() => _newFiles.addAll(prepared));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _cropExisting(int index) async {
    final photo = _existing[index];
    try {
      final response = await Dio().get<List<int>>(
        photo.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final temp = File(
        '${Directory.systemTemp.path}/edit_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await temp.writeAsBytes(response.data ?? []);
      final cropped = await cropSquareImage(temp);
      if (cropped == null || !mounted) return;
      setState(() {
        _existing.removeAt(index);
        _newFiles.add(cropped);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not crop that photo. Try re-adding it.')),
        );
      }
    }
  }

  Future<void> _cropNew(int index) async {
    final cropped = await cropSquareImage(_newFiles[index]);
    if (cropped == null || !mounted) return;
    setState(() => _newFiles[index] = cropped);
  }

  Future<void> _put(String url, File file, String contentType) async {
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

  Future<void> _save() async {
    if (_photoCount < 1) {
      setState(() => _error = 'Add at least one photo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final uploadedKeys = <String>[];
      if (_newFiles.isNotEmpty) {
        final urls = await api.post('/me/patterns/${widget.patternId}/upload-urls', data: {
          'imageCount': _newFiles.length,
        });
        final slots = (urls['images'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        if (slots.length != _newFiles.length) {
          throw ApiException('Could not prepare image uploads.');
        }
        await Future.wait([
          for (var i = 0; i < slots.length; i++)
            _put(
              slots[i]['uploadUrl'] as String,
              _newFiles[i],
              slots[i]['contentType'] as String? ?? 'image/jpeg',
            ),
        ]);
        uploadedKeys.addAll(slots.map((s) => s['key'] as String));
      }

      final imageKeys = [
        ..._existing.map((e) => e.key),
        ...uploadedKeys,
      ];

      await api.patch('/me/patterns/${widget.patternId}', {
        'title': _title.text.trim(),
        'patternUrl': _url.text.trim(),
        'imageKeys': imageKeys,
      });

      ref.invalidate(myPatternsProvider);
      ref.invalidate(patternsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern updated')));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save changes.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit pattern')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_isFree ? 'Free' : 'Paid'}${_createdAt != null ? ' · Pricing can’t be changed.' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Pattern name')),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: InputDecoration(
              labelText: _isFree && _hasPdf ? 'Pattern URL (optional)' : 'Pattern URL',
            ),
          ),
          const SizedBox(height: 16),
          Text('Photos', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _existing.length; i++)
                _EditPhotoTile(
                  isCover: i == 0,
                  onCrop: () => _cropExisting(i),
                  onRemove: () => setState(() => _existing.removeAt(i)),
                  child: CachedNetworkImage(imageUrl: _existing[i].url, fit: BoxFit.contain),
                ),
              for (var i = 0; i < _newFiles.length; i++)
                _EditPhotoTile(
                  isCover: _existing.isEmpty && i == 0,
                  onCrop: () => _cropNew(i),
                  onRemove: () => setState(() => _newFiles.removeAt(i)),
                  child: Image.file(_newFiles[i], fit: BoxFit.contain),
                ),
              if (_photoCount < AppConstants.instance.maxPatternImages)
                SizedBox(
                  width: 112,
                  height: 112,
                  child: OutlinedButton(
                    onPressed: _preparing || _saving ? null : _addPhotos,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _preparing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined),
                              SizedBox(height: 4),
                              Text('Add', textAlign: TextAlign.center),
                            ],
                          ),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving || _preparing ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}

class _EditPhotoTile extends StatelessWidget {
  const _EditPhotoTile({
    required this.child,
    required this.isCover,
    required this.onCrop,
    required this.onRemove,
  });

  final Widget child;
  final bool isCover;
  final VoidCallback onCrop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(color: AppColors.background, child: child),
            ),
          ),
          if (isCover)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Cover', style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
          Positioned(
            left: 2,
            bottom: 2,
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.card.withValues(alpha: 0.95),
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onCrop,
              icon: const Icon(Icons.crop, size: 16),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.card.withValues(alpha: 0.95),
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
