import 'dart:ui';

import 'brand_mark_data.dart';

final brandMarkVectorPaths = brandMarkPaths.map((commands) {
  final path = Path();
  for (final command in commands) {
    switch (command.first.toInt()) {
      case 0:
        path.moveTo(command[1], command[2]);
      case 1:
        path.lineTo(command[1], command[2]);
      case 2:
        path.cubicTo(
          command[1],
          command[2],
          command[3],
          command[4],
          command[5],
          command[6],
        );
      case 3:
        path.quadraticBezierTo(command[1], command[2], command[3], command[4]);
      case 4:
        path.close();
    }
  }
  return path;
}).toList();

void paintBrandMark(Canvas canvas) {
  final paint = Paint()
    ..color = const Color(brandMarkColor)
    ..isAntiAlias = true;
  for (final path in brandMarkVectorPaths) {
    canvas.drawPath(path, paint);
  }
}
