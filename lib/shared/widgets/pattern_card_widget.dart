import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/slugify.dart';
import 'arrow_big_up_icon.dart';
import 'photo_viewer.dart';
import 'save_board_sheet.dart';
import 'in_app_webview.dart';

class PatternCardWidget extends ConsumerStatefulWidget {
  const PatternCardWidget({
    super.key,
    required this.pattern,
    required this.rank,
    this.rankPeriod = 'all',
    this.showRank = true,
  });

  final PatternCard pattern;
  final int rank;
  final String rankPeriod;
  final bool showRank;

  @override
  ConsumerState<PatternCardWidget> createState() => _PatternCardWidgetState();
}

class _PatternCardWidgetState extends ConsumerState<PatternCardWidget> {
  bool _voting = false;
  bool _saving = false;
  bool _ctaLoading = false;
  late bool _saved;
  late bool _voted;
  late int _voteCount;
  int _imageIndex = 0;
  late final PageController _imageController;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _syncFromPattern();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PatternCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern.id != widget.pattern.id ||
        oldWidget.pattern.saved != widget.pattern.saved ||
        oldWidget.pattern.voted != widget.pattern.voted ||
        oldWidget.pattern.voteCount != widget.pattern.voteCount) {
      _syncFromPattern();
    }
    if (oldWidget.pattern.id != widget.pattern.id) {
      _imageIndex = 0;
      if (_imageController.hasClients) {
        _imageController.jumpToPage(0);
      }
    }
  }

  void _syncFromPattern() {
    _saved = widget.pattern.saved;
    _voted = widget.pattern.voted;
    _voteCount = widget.pattern.voteCount;
  }

  Map<String, dynamic>? get _voteQuery =>
      widget.rankPeriod == 'all' ? null : {'period': widget.rankPeriod};

  bool get _onPodium => widget.showRank && widget.rank <= 3;

  (Color bg, Color border, double borderWidth, List<BoxShadow> shadows) _rankStyle() {
    // Matches web globals.css --shadow / --shadow-rank-* tokens.
    if (!widget.showRank) {
      return (
        AppColors.card,
        AppColors.border,
        1,
        const [
          BoxShadow(color: Color(0x383D2F4A), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x143D2F4A), blurRadius: 6, spreadRadius: -2, offset: Offset(0, 2)),
        ],
      );
    }
    return switch (widget.rank) {
      1 => (
          AppColors.rank1Bg,
          AppColors.rank1Border,
          2,
          const [
            BoxShadow(color: Color(0x663D2F4A), blurRadius: 32, spreadRadius: -8, offset: Offset(0, 12)),
            BoxShadow(color: Color(0x2E3D2F4A), blurRadius: 12, spreadRadius: -3, offset: Offset(0, 4)),
          ],
        ),
      2 => (
          AppColors.rank2Bg,
          AppColors.rank2Border,
          2,
          const [
            BoxShadow(color: Color(0x573D2F4A), blurRadius: 28, spreadRadius: -8, offset: Offset(0, 10)),
            BoxShadow(color: Color(0x243D2F4A), blurRadius: 10, spreadRadius: -3, offset: Offset(0, 3)),
          ],
        ),
      3 => (
          AppColors.rank3Bg,
          AppColors.rank3Border,
          1,
          const [
            BoxShadow(color: Color(0x473D2F4A), blurRadius: 24, spreadRadius: -7, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x1F3D2F4A), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 3)),
          ],
        ),
      _ => (
          AppColors.card,
          AppColors.border,
          1,
          const [
            BoxShadow(color: Color(0x383D2F4A), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 6)),
            BoxShadow(color: Color(0x143D2F4A), blurRadius: 6, spreadRadius: -2, offset: Offset(0, 2)),
          ],
        ),
    };
  }

  (Color bg, Color fg) _rankBadgeColors() {
    return switch (widget.rank) {
      1 => (AppColors.primaryStrong, AppColors.foreground),
      2 || 3 => (AppColors.primary, AppColors.foreground),
      _ => (AppColors.card, AppColors.muted),
    };
  }

  (Color bg, Color fg, Color border) _voteColors() {
    // Matches web `voteButtonClasses` — same for every rank.
    if (_voted) {
      return (AppColors.accent, AppColors.accentForeground, AppColors.accent);
    }
    return (Colors.white, AppColors.accent, AppColors.accent);
  }

  (Color bg, Color fg) _pricePillColors() {
    if (_onPodium) {
      return (AppColors.card, widget.pattern.isFree ? AppColors.accent : AppColors.foreground);
    }
    return (
      AppColors.primary.withValues(alpha: widget.pattern.isFree ? 0.2 : 0.3),
      widget.pattern.isFree ? AppColors.accent : AppColors.foreground,
    );
  }

  Future<void> _toggleVote() async {
    if (ref.read(sessionProvider) == null) {
      if (mounted) context.go('/profile');
      return;
    }
    setState(() => _voting = true);
    HapticFeedback.lightImpact();
    final previousVoted = _voted;
    final previousCount = _voteCount;
    setState(() {
      _voted = !_voted;
      _voteCount = (_voteCount + (_voted ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post('/patterns/${widget.pattern.id}/vote', query: _voteQuery);
      final voted = result['voted'] as bool?;
      final voteCount = result['voteCount'] as num?;
      if (voted != null && voteCount != null && mounted) {
        setState(() {
          _voted = voted;
          _voteCount = voteCount.toInt();
        });
      }
      ref.invalidate(patternsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _voted = previousVoted;
          _voteCount = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _toggleSave() async {
    if (ref.read(sessionProvider) == null) {
      if (mounted) context.go('/profile');
      return;
    }
    setState(() => _saving = true);
    final previous = _saved;
    try {
      final api = ref.read(apiClientProvider);
      if (_saved) {
        setState(() => _saved = false);
        await api.delete('/patterns/${widget.pattern.id}/save');
      } else {
        setState(() => _saved = true);
        await api.post('/patterns/${widget.pattern.id}/save');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Saved'),
              action: SnackBarAction(
                label: 'Move',
                onPressed: () => _openSaveSheet(),
              ),
            ),
          );
        }
      }
      invalidatePatternSaveState(ref, widget.pattern.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saved = previous);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSaveSheet() async {
    await showSaveBoardSheet(context, ref, widget.pattern.id);
    invalidatePatternSaveState(ref, widget.pattern.id);
  }

  Future<void> _onCta() async {
    final pattern = widget.pattern;
    final showDownload = pattern.isFree && pattern.hasPdf;
    final api = ref.read(apiClientProvider);
    if (showDownload) {
      setState(() => _ctaLoading = true);
      try {
        Analytics.trackPatternCta(api, pattern.id, 'pdf');
        final result = await api.getData(
              '/patterns/${pattern.id}/pdf',
              map: (j) => j as Map<String, dynamic>,
            );
        final url = result['url'] as String?;
        if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } finally {
        if (mounted) setState(() => _ctaLoading = false);
      }
      return;
    }
    if (pattern.patternUrl != null) {
      Analytics.trackPatternCta(api, pattern.id, 'view');
      if (mounted) {
        await openInAppWebView(
          context,
          url: pattern.patternUrl!,
          title: pattern.title,
        );
      }
    }
  }

  void _openGallery() {
    final images = widget.pattern.imageUrls;
    if (images.isEmpty) return;
    showNetworkPhotoViewer(
      context,
      imageUrls: images,
      initialIndex: _imageIndex.clamp(0, images.length - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pattern = widget.pattern;
    final (bg, border, borderWidth, shadows) = _rankStyle();
    final (badgeBg, badgeFg) = _rankBadgeColors();
    final (voteBg, voteFg, voteBorder) = _voteColors();
    final (pillBg, pillFg) = _pricePillColors();
    final showDownload = pattern.isFree && pattern.hasPdf;
    final showView = !showDownload && pattern.patternUrl != null;
    final images = pattern.imageUrls;
    final radius = BorderRadius.circular(16);

    return Padding(
      padding: EdgeInsets.only(top: widget.showRank ? 8 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Outer height from outer width. Do not size Row children to this
              // value — BoxDecoration.border insets the child, so fixed half×half
              // children overflow by ~2×borderWidth.
              final height = constraints.maxWidth / 2;
              return SizedBox(
                height: height,
                child: GestureDetector(
                  onTap: _openGallery,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    // Border + shadow on the outer shell so the frame is visible
                    // immediately (before images load) and isn’t covered by content.
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: radius,
                      border: Border.all(color: border, width: borderWidth),
                      boxShadow: shadows,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        (16 - borderWidth).clamp(0, 16),
                      ),
                      child: Row(
                        children: [
                          // Square pane from inner height so border inset can't
                          // make the gallery slightly wider than tall.
                          AspectRatio(
                            aspectRatio: 1,
                            child: _buildGallery(images, bg),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            pattern.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              height: 1.2,
                                              color: AppColors.foreground,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          GestureDetector(
                                            behavior: HitTestBehavior.translucent,
                                            onTap: () => context.push(creatorPath(pattern.designerName)),
                                            child: _ExpandHitTest(
                                              vertical: 12,
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: Text(
                                                  pattern.designerName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: AppColors.foreground,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: AppColors.foreground,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: pillBg,
                                              borderRadius: BorderRadius.circular(999),
                                              boxShadow: _onPodium
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.accent.withValues(alpha: 0.08),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 1),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Text(
                                              pattern.isFree ? 'Free' : 'Paid',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: pillFg,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 36,
                                          child: OutlinedButton(
                                            onPressed: _voting ? null : _toggleVote,
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: voteBg,
                                              foregroundColor: voteFg,
                                              side: BorderSide(color: voteBorder),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              shape: const StadiumBorder(),
                                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ArrowBigUpIcon(
                                                  size: 20,
                                                  color: voteFg,
                                                  filled: _voted,
                                                ),
                                                const SizedBox(width: 2),
                                                Text('$_voteCount'),
                                              ],
                                            ),
                                          ),
                                        ).animate(target: _voted ? 1 : 0).scale(
                                              begin: const Offset(1, 1),
                                              end: const Offset(1.06, 1.06),
                                              duration: 280.ms,
                                            ),
                                      ),
                                      if (showDownload || showView) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: FilledButton(
                                              onPressed: _ctaLoading ? null : _onCta,
                                              style: FilledButton.styleFrom(
                                                backgroundColor: AppColors.accent,
                                                foregroundColor: AppColors.accentForeground,
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                shape: const StadiumBorder(),
                                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                              child: Text(
                                                _ctaLoading
                                                    ? '…'
                                                    : showDownload
                                                        ? 'Download'
                                                        : 'View',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.showRank)
            Positioned(
              left: -6,
              top: -14,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: widget.rank > 3 ? Border.all(color: AppColors.border) : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${widget.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: badgeFg,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildGallery(List<String> images, Color bg) {
    return ColoredBox(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            const Center(child: Text('No image', style: TextStyle(color: AppColors.muted, fontSize: 12)))
          else
            PageView.builder(
              controller: _imageController,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _imageIndex = i),
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                );
              },
            ),
          Positioned(
            right: 8,
            top: 8,
            child: _GlassCircleButton(
              size: 30,
              backgroundAlpha: 0.45,
              blurSigma: 4,
              onTap: _saving ? null : _toggleSave,
              onLongPress: _saving ? null : _openSaveSheet,
              child: Icon(
                _saved ? Icons.bookmark : Icons.bookmark_outline,
                size: 16,
                color: _saved ? AppColors.accent : AppColors.foreground,
              ),
            ),
          ),
          if (images.length > 1) ...[
            Positioned(
              left: 6,
              bottom: 6,
              child: _GalleryArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  final next = (_imageIndex - 1).clamp(0, images.length - 1);
                  _imageController.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _GalleryArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  final next = (_imageIndex + 1).clamp(0, images.length - 1);
                  _imageController.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GalleryArrowButton extends StatelessWidget {
  const _GalleryArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassCircleButton(
      size: 28,
      backgroundAlpha: 0.35,
      blurSigma: 2,
      onTap: onTap,
      child: Icon(icon, size: 20, color: AppColors.foreground),
    );
  }
}

/// Matches web `bg-card/35`–`/45` + light backdrop blur on gallery controls.
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.size,
    required this.backgroundAlpha,
    required this.blurSigma,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final double size;
  final double backgroundAlpha;
  final double blurSigma;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Material(
          color: AppColors.card.withValues(alpha: backgroundAlpha),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expands hit-testing beyond the child's layout size without changing layout.
class _ExpandHitTest extends SingleChildRenderObjectWidget {
  const _ExpandHitTest({
    required this.vertical,
    required Widget child,
  }) : super(child: child);

  final double vertical;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderExpandHitTest(vertical: vertical);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderExpandHitTest).vertical = vertical;
  }
}

class _RenderExpandHitTest extends RenderProxyBox {
  _RenderExpandHitTest({required double vertical}) : _vertical = vertical;

  double _vertical;

  set vertical(double value) {
    if (_vertical == value) return;
    _vertical = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final expanded = Rect.fromLTRB(
      0,
      -_vertical,
      size.width,
      size.height + _vertical,
    );
    if (!expanded.contains(position)) return false;

    if (child?.hitTest(result, position: position) ?? false) {
      return true;
    }

    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
