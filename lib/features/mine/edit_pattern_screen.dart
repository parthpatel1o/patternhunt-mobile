import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/images/square_crop.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_icons.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/pattern_option_chip.dart';
import '../../shared/widgets/reorderable_photo_grid.dart';

sealed class _EditPhoto {
  _EditPhoto({required this.id});
  final String id;
}

class _ExistingPhoto extends _EditPhoto {
  _ExistingPhoto({required super.id, required this.key, required this.url});
  final String key;
  final String url;
}

class _NewPhoto extends _EditPhoto {
  _NewPhoto({required super.id, required this.file});
  File file;
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
  late String _category;
  bool _hasPdf = false;
  bool _coverNotSquare = false;
  String? _createdAt;
  String? _error;
  final List<_EditPhoto> _photos = [];

  static const _tileSize = 112.0;
  static var _idCounter = 0;

  static String _newId() =>
      'p-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  @override
  void initState() {
    super.initState();
    _category = AppConstants.instance.defaultRankBoardCategory;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _syncCoverSquare() async {
    if (_photos.isEmpty) {
      if (!mounted) return;
      setState(() => _coverNotSquare = false);
      return;
    }
    try {
      final cover = _photos.first;
      final square = switch (cover) {
        _NewPhoto(:final file) => await isNearlySquareFile(file),
        _ExistingPhoto(:final url) => await isNearlySquareUrl(url),
      };
      if (!mounted) return;
      setState(() => _coverNotSquare = !square);
    } catch (_) {
      if (mounted) setState(() => _coverNotSquare = false);
    }
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
        final loadedCategory = data['categorySlug'] as String?;
        final categories = AppConstants.instance.categories;
        _category = categories.any((c) => c.slug == loadedCategory)
            ? loadedCategory!
            : AppConstants.instance.defaultRankBoardCategory;
        _hasPdf = data['hasPdf'] == true;
        _createdAt = data['createdAt'] as String?;
        _photos
          ..clear()
          ..addAll(
            ((data['images'] as List<dynamic>?) ?? []).map((item) {
              final map = item as Map<String, dynamic>;
              return _ExistingPhoto(
                id: _newId(),
                key: map['key'] as String,
                url: map['url'] as String,
              );
            }),
          );
        _loading = false;
      });
      await _syncCoverSquare();
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
    final remaining = max - _photos.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final single = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      picked = single == null ? const [] : [single];
    } else {
      picked = await picker.pickMultiImage(imageQuality: 95, limit: remaining);
    }
    if (picked.isEmpty || !mounted) return;

    final coverIndexBefore = _photos.length;
    setState(() => _preparing = true);
    try {
      final prepared = <_NewPhoto>[];
      for (final xfile in picked.take(remaining)) {
        prepared.add(
          _NewPhoto(id: _newId(), file: await _compress(File(xfile.path))),
        );
      }
      if (!mounted) return;
      setState(() => _photos.addAll(prepared));
      if (coverIndexBefore == 0 && prepared.isNotEmpty) {
        await _syncCoverSquare();
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _movePhoto(int from, int to) {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= _photos.length ||
        to >= _photos.length) {
      return;
    }
    final coverChanged = from == 0 || to == 0;
    setState(() {
      final item = _photos.removeAt(from);
      _photos.insert(to, item);
    });
    if (coverChanged) {
      _syncCoverSquare();
    }
  }

  Future<File> _fileForCrop(_EditPhoto photo) async {
    if (photo is _NewPhoto) return photo.file;
    final existing = photo as _ExistingPhoto;
    final response = await Dio().get<List<int>>(
      existing.url,
      options: Options(responseType: ResponseType.bytes),
    );
    final temp = File(
      '${Directory.systemTemp.path}/edit_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await temp.writeAsBytes(response.data ?? []);
    return temp;
  }

  Future<void> _cropAt(int index) async {
    final photo = _photos[index];
    try {
      final source = await _fileForCrop(photo);
      final cropped = await cropSquareImage(source);
      if (cropped == null || !mounted) return;
      setState(() {
        _photos[index] = _NewPhoto(id: photo.id, file: cropped);
        if (index == 0) _coverNotSquare = false;
      });
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Could not crop that photo. Try re-adding it.',
        );
      }
    }
  }

  Future<void> _removeAt(int index) async {
    final wasCover = index == 0;
    setState(() => _photos.removeAt(index));
    if (wasCover) await _syncCoverSquare();
  }

  Widget _photoPreview(_EditPhoto photo, {BoxFit fit = BoxFit.contain}) {
    return switch (photo) {
      _ExistingPhoto(:final url) => CachedNetworkImage(imageUrl: url, fit: fit),
      _NewPhoto(:final file) => Image.file(file, fit: fit),
    };
  }

  Widget _photoTile(int index) {
    final photo = _photos[index];
    final coverBad = index == 0 && _coverNotSquare;
    return SizedBox(
      width: _tileSize,
      height: _tileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: coverBad
              ? Border.all(color: Theme.of(context).colorScheme.error, width: 2)
              : Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: AppColors.background,
                  child: _photoPreview(photo),
                ),
              ),
            ),
            if (index == 0)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Cover',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            Positioned(
              left: 2,
              bottom: 2,
              child: Material(
                color: AppColors.card.withValues(alpha: 0.95),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving || _preparing ? null : () => _cropAt(index),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(Icons.crop, size: 16),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: Material(
                color: AppColors.card.withValues(alpha: 0.95),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving || _preparing ? null : () => _removeAt(index),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoFeedback(int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: AppColors.background,
        child: _photoPreview(_photos[index]),
      ),
    );
  }

  Widget _addPhotosCard(int remaining) {
    return SizedBox(
      width: _tileSize,
      height: _tileSize,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _preparing || _saving ? null : _addPhotos,
          child: CustomPaint(
            painter: _DashedBorderPainter(color: AppColors.border, radius: 16),
            child: Center(
              child: _preparing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.accent,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add photos',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                          ),
                          Text(
                            '$remaining remaining',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
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
      throw ApiException(
        'Upload failed (${response.statusCode ?? 'unknown'}).',
      );
    }
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (_photos.isEmpty) {
      setState(() => _error = 'Add at least one photo.');
      return;
    }
    if (!_isFree && url.isEmpty) {
      setState(() => _error = 'Paid patterns need an external pattern URL');
      return;
    }
    if (_isFree && !_hasPdf && url.isEmpty) {
      setState(
        () => _error = 'Free patterns need a PDF or an external pattern URL',
      );
      return;
    }

    final cover = _photos.first;
    final square = switch (cover) {
      _NewPhoto(:final file) => await isNearlySquareFile(file),
      _ExistingPhoto(:final url) => await isNearlySquareUrl(url),
    };
    if (!square) {
      if (!mounted) return;
      setState(() {
        _coverNotSquare = true;
        _error = 'Your cover image needs to be a square image.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final newPhotos = _photos.whereType<_NewPhoto>().toList();
      final uploadedKeys = <String>[];
      if (newPhotos.isNotEmpty) {
        final urls = await api.post(
          '/me/patterns/${widget.patternId}/upload-urls',
          data: {'imageCount': newPhotos.length},
        );
        final slots = (urls['images'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        if (slots.length != newPhotos.length) {
          throw ApiException('Could not prepare image uploads.');
        }
        await Future.wait([
          for (var i = 0; i < slots.length; i++)
            _put(
              slots[i]['uploadUrl'] as String,
              newPhotos[i].file,
              slots[i]['contentType'] as String? ?? 'image/jpeg',
            ),
        ]);
        uploadedKeys.addAll(slots.map((s) => s['key'] as String));
      }

      var newIndex = 0;
      final imageKeys = _photos.map((photo) {
        if (photo is _ExistingPhoto) return photo.key;
        return uploadedKeys[newIndex++];
      }).toList();

      await api.patch('/me/patterns/${widget.patternId}', {
        'title': _title.text.trim(),
        'patternUrl': _url.text.trim(),
        'isFree': _isFree,
        'categorySlug': _category,
        'imageKeys': imageKeys,
      });

      ref.invalidate(myPatternsProvider);
      ref.invalidate(patternsProvider);
      ref.invalidate(patternDetailProvider(widget.patternId));
      if (mounted) {
        HapticFeedback.lightImpact();
        showAppSnackBar(context, message: 'Pattern updated');
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

  String get _detailsHint {
    final created = _createdAt == null ? null : DateTime.tryParse(_createdAt!);
    if (created == null) return '';
    return 'Launched ${DateFormat('d MMM yyyy').format(created.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textTheme = Theme.of(context).textTheme;

    InputDecoration fieldDecoration(String? hint) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      );
    }

    Widget fieldLabel(String text) {
      return Text(
        text,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
    }

    final remaining = AppConstants.instance.maxPatternImages - _photos.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit pattern')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
        children: [
          _EditSection(
            title: 'Details',
            hint: _detailsHint.isEmpty ? null : _detailsHint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                fieldLabel('Pattern name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 80,
                  enabled: !_saving,
                  decoration: fieldDecoration('Tiny frog plushie')
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 16),
                fieldLabel('Is this pattern free or paid?'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PatternOptionChip(
                        selected: !_isFree,
                        label: 'Paid',
                        onTap: _saving
                            ? null
                            : () => setState(() => _isFree = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PatternOptionChip(
                        selected: _isFree,
                        label: 'Free',
                        onTap: _saving
                            ? null
                            : () => setState(() => _isFree = true),
                      ),
                    ),
                  ],
                ),
                if (!_isFree && _hasPdf) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Saving as paid will remove the uploaded PDF.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                fieldLabel('Category'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in AppConstants.instance.categories)
                      PatternOptionChip(
                        selected: _category == c.slug,
                        icon: categoryIcon(c.slug),
                        label: c.name,
                        onTap: _saving
                            ? null
                            : () => setState(() => _category = c.slug),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                fieldLabel(
                  _isFree && _hasPdf
                      ? 'Pattern URL (optional if you already have a PDF)'
                      : 'Pattern URL',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  enabled: !_saving,
                  decoration: fieldDecoration('https://'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _EditSection(
            title: 'Photos',
            hint: 'Choose one or more photos.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReorderablePhotoGrid(
                  itemCount: _photos.length,
                  tileSize: _tileSize,
                  enabled: !_saving && !_preparing,
                  tileBuilder: (context, index) => _photoTile(index),
                  feedbackBuilder: (context, index) => _photoFeedback(index),
                  onReorder: _movePhoto,
                  trailing: remaining > 0 ? _addPhotosCard(remaining) : null,
                ),
                if (_coverNotSquare) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Your cover image needs to be a square image.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || _preparing ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentForeground,
                    disabledBackgroundColor: AppColors.accent.withValues(
                      alpha: 0.6,
                    ),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  const _EditSection({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x383D2F4A),
            blurRadius: 20,
            spreadRadius: -6,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x143D2F4A),
            blurRadius: 6,
            spreadRadius: -2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
