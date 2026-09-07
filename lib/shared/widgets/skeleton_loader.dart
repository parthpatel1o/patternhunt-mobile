import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, required this.width, required this.height, this.borderRadius = 12});

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(AppColors.border, AppColors.card, _controller.value),
          ),
        );
      },
    );
  }
}

class PatternCardSkeleton extends StatelessWidget {
  const PatternCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final half = constraints.maxWidth / 2;
          return SizedBox(
            height: half,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: half,
                      height: half,
                      child: const ColoredBox(color: AppColors.background),
                    ),
                    SizedBox(
                      width: half,
                      height: half,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 140, height: 16, borderRadius: 6),
                            SizedBox(height: 8),
                            SkeletonBox(width: 100, height: 12, borderRadius: 6),
                            SizedBox(height: 10),
                            SkeletonBox(width: 48, height: 20, borderRadius: 999),
                            Spacer(),
                            Row(
                              children: [
                                Expanded(child: SkeletonBox(width: 80, height: 36, borderRadius: 999)),
                                SizedBox(width: 8),
                                Expanded(child: SkeletonBox(width: 80, height: 36, borderRadius: 999)),
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
    );
  }
}
