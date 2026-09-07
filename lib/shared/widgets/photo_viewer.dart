import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
    barrierColor: Colors.black.withValues(alpha: 0.9),
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
  late final ScrollController _thumbController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _index);
    _thumbController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollThumbIntoView(animated: false));
  }

  @override
  void dispose() {
    _controller.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final next = index.clamp(0, widget.imageUrls.length - 1);
    setState(() => _index = next);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    _scrollThumbIntoView();
  }

  void _scrollThumbIntoView({bool animated = true}) {
    if (!_thumbController.hasClients) return;
    const thumbWidth = 64.0;
    const gap = 8.0;
    final target = (_index * (thumbWidth + gap)) - 40;
    final offset = target.clamp(0.0, _thumbController.position.maxScrollExtent);
    if (animated) {
      _thumbController.animateTo(offset, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    } else {
      _thumbController.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverSuffix = widget.showCoverHint && _index == 0 ? ' · Cover' : '';
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Text(
                    '${_index + 1} / ${widget.imageUrls.length}$coverSuffix',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.imageUrls.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                  _scrollThumbIntoView();
                },
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
            ),
            if (widget.imageUrls.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: SizedBox(
                  height: 72,
                  child: ListView.separated(
                    controller: _thumbController,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.imageUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final selected = i == _index;
                      return GestureDetector(
                        onTap: () => _goTo(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.25),
                              width: selected ? 2.5 : 1,
                            ),
                            color: AppColors.accent.withValues(alpha: 0.35),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: widget.imageUrls[i],
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
