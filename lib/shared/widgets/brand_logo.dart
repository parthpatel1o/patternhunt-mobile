import 'package:flutter/material.dart';

import '../branding/brand_mark_paths.dart';

/// Paints the shared brand outline at the device's native resolution.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Pattern Hunt logo',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    ),
  );
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024, size.height / 1024);
    paintBrandMark(canvas);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
