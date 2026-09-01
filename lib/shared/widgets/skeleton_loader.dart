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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: const [
            SkeletonBox(width: 96, height: 96, borderRadius: 16),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 18),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 14),
                  SizedBox(height: 12),
                  SkeletonBox(width: 80, height: 32, borderRadius: 999),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
