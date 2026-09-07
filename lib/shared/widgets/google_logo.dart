import 'package:flutter/material.dart';

/// Multicolor Google "G" mark for auth buttons.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - stroke / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Blue arc (right)
    paint.color = _blue;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -0.4, 1.6, false, paint);

    // Green arc (bottom-left)
    paint.color = _green;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 1.2, 1.1, false, paint);

    // Yellow arc (bottom)
    paint.color = _yellow;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 2.3, 0.9, false, paint);

    // Red arc (top-left)
    paint.color = _red;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3.2, 1.2, false, paint);

    // Blue horizontal bar of the G
    final bar = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    final barHeight = stroke;
    final barTop = center.dy - barHeight / 2;
    canvas.drawRRect(
      RRect.fromLTRBR(
        center.dx - stroke * 0.15,
        barTop,
        size.width - stroke * 0.15,
        barTop + barHeight,
        Radius.circular(barHeight / 4),
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
