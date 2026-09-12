import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  void _syncPulse() {
    if (AppMotion.reduced(context)) {
      if (_controller.isAnimating) _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A looping pulse is exactly what reduced motion asks us to drop; hold the
    // placeholder at a steady mid tint instead.
    if (AppMotion.reduced(context)) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(
              AppColors.background,
              AppColors.border.withValues(alpha: 0.85),
              0.5,
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Soft pulse between background and a light border tint — avoids harsh
        // border↔card flashing that looked broken on white cards.
        final color = Color.lerp(
          AppColors.background,
          AppColors.border.withValues(alpha: 0.85),
          _controller.value,
        );
        // Prefer SizedBox sizing so null width/height can expand inside Expanded.
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class PatternCardSkeleton extends StatelessWidget {
  const PatternCardSkeleton({super.key});

  static const _radius = 16.0;
  static const _shadows = [
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
  ];

  @override
  Widget build(BuildContext context) {
    // Matches PatternCardWidget layout: top inset for rank badge, half/half row.
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Outer height from outer width; Row halves use Expanded so they
              // respect BoxDecoration.border inset (same as PatternCardWidget).
              final height = constraints.maxWidth / 2;
              return SizedBox(
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(color: AppColors.border),
                    boxShadow: _shadows,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius - 1),
                    child: Row(
                      children: [
                        const Expanded(child: SkeletonBox(borderRadius: 0)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: ClipRect(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          SkeletonBox(
                                            height: 14,
                                            borderRadius: 6,
                                          ),
                                          SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: 120,
                                              child: SkeletonBox(
                                                height: 14,
                                                borderRadius: 6,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: 88,
                                              child: SkeletonBox(
                                                height: 12,
                                                borderRadius: 6,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: 48,
                                              child: SkeletonBox(
                                                height: 18,
                                                borderRadius: 999,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Row(
                                  children: [
                                    Expanded(
                                      child: SkeletonBox(
                                        height: 34,
                                        borderRadius: 999,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: SkeletonBox(
                                        height: 34,
                                        borderRadius: 999,
                                      ),
                                    ),
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
              );
            },
          ),
          // Rank badge ghost — overlaps top-left like web loading.tsx / PatternCardWidget
          const Positioned(
            left: -6,
            top: -14,
            child: SkeletonBox(width: 40, height: 36, borderRadius: 999),
          ),
        ],
      ),
    );
  }
}
