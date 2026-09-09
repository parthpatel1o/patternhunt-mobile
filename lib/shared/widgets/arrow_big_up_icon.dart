import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Rounded upward arrow.
/// - Outline: white fill + [color] stroke
/// - Filled (voted): solid [color] (web uses accent-foreground on accent button)
class ArrowBigUpIcon extends StatelessWidget {
  const ArrowBigUpIcon({
    super.key,
    this.size = 20,
    this.color = AppColors.accent,
    this.filled = false,
    this.strokeWidth = 1.75,
  });

  final double size;
  final Color color;
  final bool filled;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _UpvoteArrowPainter(
          color: color,
          filled: filled,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _UpvoteArrowPainter extends CustomPainter {
  _UpvoteArrowPainter({
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  final Color color;
  final bool filled;
  final double strokeWidth;

  /// Rounded ArrowBigUp silhouette in a 24×24 viewBox.
  static Path _arrowPath(Size size) {
    final sx = size.width / 24;
    final sy = size.height / 24;
    Offset o(double x, double y) => Offset(x * sx, y * sy);
    Radius rad(double v) => Radius.circular(v * ((sx + sy) / 2));

    return Path()
      ..moveTo(o(9, 19).dx, o(9, 19).dy)
      ..arcToPoint(o(10, 20), radius: rad(1), clockwise: false)
      ..lineTo(o(14, 20).dx, o(14, 20).dy)
      ..arcToPoint(o(15, 19), radius: rad(1), clockwise: false)
      ..lineTo(o(15, 13).dx, o(15, 13).dy)
      ..arcToPoint(o(16, 12), radius: rad(1), clockwise: true)
      ..lineTo(o(19.293, 12).dx, o(19.293, 12).dy)
      ..arcToPoint(o(19.793, 10.793), radius: rad(0.707), clockwise: false)
      ..lineTo(o(12.707, 3.707).dx, o(12.707, 3.707).dy)
      ..arcToPoint(o(11.293, 3.707), radius: rad(1), clockwise: false)
      ..lineTo(o(4.207, 10.793).dx, o(4.207, 10.793).dy)
      ..arcToPoint(o(4.707, 12), radius: rad(0.707), clockwise: false)
      ..lineTo(o(8, 12).dx, o(8, 12).dy)
      ..arcToPoint(o(9, 13), radius: rad(1), clockwise: true)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _arrowPath(size);

    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * (size.width / 24)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UpvoteArrowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.filled != filled ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
