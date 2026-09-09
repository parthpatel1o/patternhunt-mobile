import 'package:flutter/material.dart';

/// Multicolor Google "G" mark for auth buttons.
///
/// Drawn from the official 24×24 Google "G" filled paths (same as web)
/// so the logo scales cleanly without stroke-edge clipping.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  // Official Google "G" paths in a 24×24 viewBox (from web GoogleLogo.tsx).
  static final Path _bluePath = Path()
    ..moveTo(22.56, 12.25)
    ..relativeCubicTo(0, -0.78, -0.07, -1.53, -0.2, -2.25)
    ..lineTo(12, 10)
    ..relativeLineTo(0, 4.26)
    ..relativeLineTo(5.92, 0)
    ..relativeCubicTo(-0.26, 1.37, -1.04, 2.53, -2.21, 3.31)
    ..relativeLineTo(0, 2.77)
    ..relativeLineTo(3.57, 0)
    ..relativeCubicTo(2.08, -1.92, 3.28, -4.74, 3.28, -8.09)
    ..close();

  static final Path _greenPath = Path()
    ..moveTo(12, 23)
    ..relativeCubicTo(2.97, 0, 5.46, -0.98, 7.28, -2.66)
    ..relativeLineTo(-3.57, -2.77)
    ..relativeCubicTo(-0.98, 0.66, -2.23, 1.06, -3.71, 1.06)
    ..relativeCubicTo(-2.86, 0, -5.29, -1.93, -6.16, -4.53)
    ..lineTo(2.18, 14.1)
    ..relativeLineTo(0, 2.84)
    ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
    ..close();

  static final Path _yellowPath = Path()
    ..moveTo(5.84, 14.09)
    ..relativeCubicTo(-0.22, -0.66, -0.35, -1.36, -0.35, -2.09)
    // SVG smooth cubic `s.13-1.43.35-2.09` (reflected control point)
    ..relativeCubicTo(0, -0.73, 0.13, -1.43, 0.35, -2.09)
    ..lineTo(5.84, 7.07)
    ..lineTo(2.18, 7.07)
    ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
    // SVG smooth cubic `s.43 3.45 1.18 4.93`
    ..cubicTo(1, 13.78, 1.43, 15.45, 2.18, 16.93)
    ..relativeLineTo(2.85, -2.22)
    ..relativeLineTo(0.81, -0.62)
    ..close();

  static final Path _redPath = Path()
    ..moveTo(12, 5.38)
    ..relativeCubicTo(1.62, 0, 3.06, 0.56, 4.21, 1.64)
    ..relativeLineTo(3.15, -3.15)
    ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
    ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
    ..relativeLineTo(3.66, 2.84)
    ..relativeCubicTo(0.87, -2.6, 3.3, -4.53, 6.16, -4.53)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);

    final paint = Paint()..isAntiAlias = true;
    paint.color = _blue;
    canvas.drawPath(_bluePath, paint);
    paint.color = _green;
    canvas.drawPath(_greenPath, paint);
    paint.color = _yellow;
    canvas.drawPath(_yellowPath, paint);
    paint.color = _red;
    canvas.drawPath(_redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
