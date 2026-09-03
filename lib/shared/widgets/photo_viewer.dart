import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Fullscreen multi-image lightbox for network URLs (home cards, detail, etc.).
void showNetworkPhotoViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  bool showCoverHint = false,
}) {
  if (imageUrls.isEmpty) return;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (dialogContext) {
      return _NetworkPhotoViewer(
        imageUrls: List<String>.from(imageUrls),
        initialIndex: initialIndex,
        showCoverHint: showCoverHint,
      );
    },
  );
}

class _NetworkPhotoViewer extends StatefulWidget {
  const _NetworkPhotoViewer({
    required this.imageUrls,
    required this.initialIndex,
    required this.showCoverHint,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final bool showCoverHint;

  @override
  State<_NetworkPhotoViewer> createState() => _NetworkPhotoViewerState();
}

class _NetworkPhotoViewerState extends State<_NetworkPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverSuffix = widget.showCoverHint && _index == 0 ? ' · Cover' : '';
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.imageUrls.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 16,
              child: Text(
                '${_index + 1} / ${widget.imageUrls.length}$coverSuffix',
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
