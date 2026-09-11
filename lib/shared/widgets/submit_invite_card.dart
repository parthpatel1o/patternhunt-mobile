import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// Last rank-board slot. Matches web `SubmitInviteCard`.
class SubmitInviteCard extends StatelessWidget {
  const SubmitInviteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxWidth / 2;
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.card,
            ),
            child: CustomPaint(
              foregroundPainter: const _DashedRRectPainter(
                color: Color(0x663D2F4A),
                radius: 16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/submit'),
                    child: Row(
                      children: [
                        SizedBox(
                          width: height,
                          child: const ColoredBox(
                            color: AppColors.background,
                            child: Center(
                              child: Text('🧶', style: TextStyle(fontSize: 36, height: 1)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Want your pattern here?',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.2,
                                        color: AppColors.foreground,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Submit it and it can climb this rank board.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 36,
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Submit Pattern',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryForeground,
                                    ),
                                  ),
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
            ),
          );
        },
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth / 2,
            strokeWidth / 2,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    canvas.drawPath(_dash(path), paint);
  }

  Path _dash(Path source) {
    const dash = 5.0;
    const gap = 4.0;
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gap;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
