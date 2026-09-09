import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Matches web `EmptyState`: dashed card, optional icon, title, description, CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.emoji,
    this.action,
  });

  final String title;
  final String description;

  /// Optional Material icon shown in a lavender square (web icon slot).
  final IconData? icon;

  /// Optional emoji (e.g. 📁) when web uses a text icon.
  final String? emoji;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasIcon = icon != null || emoji != null;

    return CustomPaint(
      painter: DashedRoundedRectPainter(
        color: AppColors.border,
        radius: 22,
        strokeWidth: 1.5,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 56),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIcon) ...[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: emoji != null
                    ? Text(emoji!, style: const TextStyle(fontSize: 24))
                    : Icon(icon, color: AppColors.accent, size: 26),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: AppColors.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStatePillButton extends StatelessWidget {
  const EmptyStatePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.accent = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent ? AppColors.accent : AppColors.primary,
          foregroundColor:
              accent ? AppColors.accentForeground : AppColors.primaryForeground,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.foreground,
        backgroundColor: AppColors.card,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      child: Text(label),
    );
  }
}

class DashedRoundedRectPainter extends CustomPainter {
  DashedRoundedRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
