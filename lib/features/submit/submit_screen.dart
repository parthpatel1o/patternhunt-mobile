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
import '../../core/images/square_crop.dart';
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

  /// Compress a photo for upload. Keeps aspect ratio; longest side capped.
  Future<File> _compressImage(File file, {img.Image? decoded}) async {
    final bytes = decoded == null ? await file.readAsBytes() : null;
    final image = decoded ?? img.decodeImage(bytes!);
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
      '${Directory.systemTemp.path}/pattern_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(output, quality: _jpegQuality));
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
        return _compressImage(source, decoded: decoded);
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

  void _moveImage(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= _images.length || to >= _images.length) {
      return;
    }
    setState(() {
      final item = _images.removeAt(from);
      _images.insert(to, item);
    });
  }

  void _openPhotoViewer(int initialIndex) {
    if (_images.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) {
        return _SubmitPhotoViewer(
          images: List<File>.from(_images),
          initialIndex: initialIndex,
        );
      },
    );
  }

  static const _tileSize = 112.0;

  Future<void> _cropImageAt(int index) async {
    final file = _images[index];
    final cropped = await cropSquareImage(file);
    if (cropped == null || !mounted) return;
    setState(() => _images[index] = cropped);
  }

  Widget _photoTile(int index) {
    final file = _images[index];
    final tile = SizedBox(
      width: _tileSize,
      height: _tileSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openPhotoViewer(index),
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
          if (index == 0)
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
            child: Material(
              color: AppColors.card.withValues(alpha: 0.95),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _cropImageAt(index),
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
                onTap: () => setState(() => _images.removeAt(index)),
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
    );

    return LongPressDraggable<int>(
      data: index,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: _tileSize,
          height: _tileSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: AppColors.background,
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) => _moveImage(details.data, index),
        builder: (context, candidate, rejected) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: candidate.isNotEmpty
                  ? Border.all(color: AppColors.accent, width: 2)
                  : null,
            ),
            child: tile,
          );
        },
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
          onTap: _preparing || _uploading ? null : _pickImages,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: AppColors.border,
              radius: 16,
            ),
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
                          const Icon(Icons.add_photo_alternate_outlined, color: AppColors.accent, size: 26),
                          const SizedBox(height: 4),
                          Text(
                            'Add photos',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                          ),
                          Text(
                            '$remaining remaining',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted),
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
        Text('Is this pattern free or paid?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ChoiceChip(
                selected: !_isFree,
                icon: Icons.attach_money,
                label: 'Paid',
                onTap: () => setState(() {
                  _isFree = false;
                  _pdf = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceChip(
                selected: _isFree,
                icon: Icons.card_giftcard_outlined,
                label: 'Free',
                onTap: () => setState(() => _isFree = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Category', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in categories)
              _ChoiceChip(
                selected: _category == c.slug,
                icon: _categoryIcon(c.slug),
                label: c.name,
                onTap: () => setState(() => _category = c.slug),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'Pattern URL')),
        if (_isFree) ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(_pdf == null ? 'Add PDF (optional)' : _pdf!.path.split('/').last),
            trailing: _pdf != null
                ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _pdf = null))
                : null,
            onTap: _pickPdf,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Choose one or more photos. Square photos preferred — tap crop on a photo if you want a square crop.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _images.length; i++) _photoTile(i),
            if (_images.length < AppConstants.instance.maxPatternImages)
              _addPhotosCard(AppConstants.instance.maxPatternImages - _images.length),
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

IconData _categoryIcon(String slug) {
  switch (slug) {
    case 'amigurumi':
      return Icons.cruelty_free_outlined;
    case 'wearables':
      return Icons.checkroom_outlined;
    case 'accessories':
      return Icons.diamond_outlined;
    default:
      return Icons.category_outlined;
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.primaryStrong : AppColors.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.primaryForeground : AppColors.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primaryForeground : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
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
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
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

class _SubmitPhotoViewer extends StatefulWidget {
  const _SubmitPhotoViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<File> images;
  final int initialIndex;

  @override
  State<_SubmitPhotoViewer> createState() => _SubmitPhotoViewerState();
}

class _SubmitPhotoViewerState extends State<_SubmitPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.file(widget.images[i], fit: BoxFit.contain),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 16,
              child: Text(
                '${_index + 1} / ${widget.images.length}${_index == 0 ? ' · Cover' : ''}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
