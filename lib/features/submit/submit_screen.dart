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
import '../../core/theme/category_icons.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/reorderable_photo_grid.dart';

class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({super.key});

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _designerName = TextEditingController();
  late String _category;
  bool _isFree = false;
  final List<File> _images = [];
  File? _pdf;
  bool _uploading = false;
  bool _preparing = false;
  bool _coverNotSquare = false;
  String? _error;
  bool _designerNameSynced = false;

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
    _designerName.dispose();
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

  Future<void> _syncCoverSquare() async {
    if (_images.isEmpty) {
      if (!mounted) return;
      setState(() => _coverNotSquare = false);
      return;
    }
    try {
      final square = await isNearlySquareFile(_images.first);
      if (!mounted) return;
      setState(() => _coverNotSquare = !square);
    } catch (_) {
      if (mounted) setState(() => _coverNotSquare = false);
    }
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

    final coverIndexBefore = _images.length;
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
      if (coverIndexBefore == 0 && prepared.isNotEmpty) {
        await _syncCoverSquare();
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _moveImage(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= _images.length || to >= _images.length) {
      return;
    }
    final coverChanged = from == 0 || to == 0;
    setState(() {
      final item = _images.removeAt(from);
      _images.insert(to, item);
    });
    if (coverChanged) {
      // Don't block the drop animation on square checks.
      _syncCoverSquare();
    }
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
    setState(() {
      _images[index] = cropped;
      if (index == 0) _coverNotSquare = false;
    });
  }

  Future<void> _removeImageAt(int index) async {
    final wasCover = index == 0;
    setState(() => _images.removeAt(index));
    if (wasCover) await _syncCoverSquare();
  }

  Widget _photoTile(int index) {
    final file = _images[index];
    final coverBad = index == 0 && _coverNotSquare;
    return SizedBox(
      width: _tileSize,
      height: _tileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: coverBad
              ? Border.all(color: Theme.of(context).colorScheme.error, width: 2)
              : null,
        ),
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
                  onTap: () => _removeImageAt(index),
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
        child: Image.file(_images[index], fit: BoxFit.contain),
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

  Future<void> _submit({required bool needsDesignerName}) async {
    final title = _title.text.trim();
    final patternUrl = _url.text.trim();
    final designerName = _designerName.text.trim();

    if (needsDesignerName && designerName.length < 2) {
      setState(() => _error = 'Enter your designer name.');
      return;
    }
    if (title.length < 2) {
      setState(() => _error = 'Title is too short');
      return;
    }
    if (_images.isEmpty) {
      setState(() => _error = 'Add at least one photo');
      return;
    }
    if (!(await isNearlySquareFile(_images.first))) {
      if (!mounted) return;
      setState(() {
        _coverNotSquare = true;
        _error = 'Your cover image needs to be a square image.';
      });
      return;
    }
    if (_isFree) {
      if (_pdf == null && patternUrl.isEmpty) {
        setState(() => _error = 'Free patterns need a PDF or an external pattern URL');
        return;
      }
    } else if (patternUrl.isEmpty) {
      setState(() => _error = 'Paid patterns need an external pattern URL');
      return;
    }
    if (patternUrl.isNotEmpty &&
        !(patternUrl.startsWith('http://') || patternUrl.startsWith('https://'))) {
      setState(() => _error = 'Pattern URL must start with http:// or https://');
      return;
    }

    setState(() {
      _error = null;
      _uploading = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      final urls = await api.post('/patterns/upload-urls', data: {
        'imageCount': _images.length,
        'hasPdf': _isFree && _pdf != null,
      });

      final imageSlots = (urls['images'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final pdfSlot = urls['pdf'] as Map<String, dynamic>?;
      if (imageSlots.length != _images.length) {
        throw ApiException('Could not prepare image uploads.');
      }
      if (_isFree && _pdf != null && pdfSlot == null) {
        throw ApiException('Could not prepare PDF upload.');
      }

      await Future.wait([
        for (var i = 0; i < imageSlots.length; i++)
          _putToSignedUrl(
            imageSlots[i]['uploadUrl'] as String,
            _images[i],
            imageSlots[i]['contentType'] as String? ?? 'image/jpeg',
          ),
        if (_isFree && _pdf != null && pdfSlot != null)
          _putToSignedUrl(
            pdfSlot['uploadUrl'] as String,
            _pdf!,
            pdfSlot['contentType'] as String? ?? 'application/pdf',
          ),
      ]);

      final payload = <String, dynamic>{
        'patternId': urls['patternId'],
        'title': title,
        'patternUrl': patternUrl,
        'isFree': _isFree,
        'categorySlug': _category,
        'imageKeys': imageSlots.map((s) => s['key']).toList(),
        'pdfKey': (_isFree && pdfSlot != null) ? pdfSlot['key'] : null,
      };
      if (needsDesignerName) {
        payload['designerName'] = designerName;
      }
      await api.post('/patterns', data: payload);

      ref.invalidate(myPatternsProvider);
      ref.invalidate(patternsProvider);
      ref.invalidate(profileProvider);
      if (mounted) {
        // Force the submitted category so preferred-category doesn't hide it.
        context.go('/?category=$_category');
        showAppSnackBar(
          context,
          message: 'Your pattern has been added.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn’t save this pattern.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final displayName = profile?.displayName?.trim() ?? '';
    final needsDesignerName =
        profile == null || !profile.isPatternDesigner || displayName.length < 2;
    if (needsDesignerName && !_designerNameSynced) {
      _designerNameSynced = true;
      if (displayName.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _designerName.text = displayName;
        });
      }
    }

    final categories = AppConstants.instance.categories;
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      children: [
        _SubmitSection(
          title: 'Pattern',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsDesignerName) ...[
                fieldLabel('Designer name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _designerName,
                  textCapitalization: TextCapitalization.words,
                  decoration: fieldDecoration('Woolly Studio'),
                ),
                const SizedBox(height: 16),
              ],
              fieldLabel('Pattern name'),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: fieldDecoration('Tiny frog plushie').copyWith(counterText: ''),
              ),
              const SizedBox(height: 16),
              fieldLabel('Is this pattern free or paid?'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceChip(
                      selected: !_isFree,
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
                      label: 'Free',
                      onTap: () => setState(() => _isFree = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              fieldLabel('Category'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    _ChoiceChip(
                      selected: _category == c.slug,
                      icon: categoryIcon(c.slug),
                      label: c.name,
                      onTap: () => setState(() => _category = c.slug),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SubmitSection(
          title: 'Photos',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose one or more photos. Drag the handle to reorder — the cover photo must be square.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ReorderablePhotoGrid(
                itemCount: _images.length,
                tileSize: _tileSize,
                enabled: !_preparing && !_uploading,
                tileBuilder: (context, index) => _photoTile(index),
                feedbackBuilder: (context, index) => _photoFeedback(index),
                onReorder: _moveImage,
                trailing: _images.length < AppConstants.instance.maxPatternImages
                    ? _addPhotosCard(
                        AppConstants.instance.maxPatternImages - _images.length,
                      )
                    : null,
              ),
              if (_coverNotSquare) ...[
                const SizedBox(height: 10),
                Text(
                  'Your cover image needs to be a square image.',
                  style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SubmitSection(
          title: 'Where to get it',
          hint: _isFree ? 'Add a link, a PDF, or both.' : 'Add the shop or listing link.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fieldLabel(
                _isFree ? 'Pattern URL (optional if you upload a PDF)' : 'Pattern URL',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: fieldDecoration('https://'),
              ),
              if (_isFree) ...[
                const SizedBox(height: 16),
                fieldLabel('PDF'),
                const SizedBox(height: 4),
                Text(
                  'Up to 20 MB.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _uploading ? null : _pickPdf,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      child: Text(_pdf == null ? 'Choose PDF' : 'Replace PDF'),
                    ),
                    if (_pdf != null) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => setState(() => _pdf = null),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          textStyle: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ],
                ),
                if (_pdf != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _pdf!.path.split('/').last,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: textTheme.bodySmall?.copyWith(color: AppColors.destructive, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _uploading || _preparing
              ? null
              : () => _submit(needsDesignerName: needsDesignerName),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.accentForeground,
            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          child: Text(_uploading ? 'Publishing…' : 'Publish pattern'),
        ),
      ],
    );
  }
}

class _SubmitSection extends StatelessWidget {
  const _SubmitSection({
    required this.title,
    required this.child,
    this.hint,
  });

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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final bool selected;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.background,
      elevation: selected ? 1 : 0,
      shadowColor: const Color(0x293D2F4A),
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.primaryForeground : AppColors.muted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
