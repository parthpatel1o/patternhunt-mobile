import 'dart:io';
import 'package:image/image.dart';

void main() {
  final src = decodeImage(File('assets/splash_logo.png').readAsBytesSync())!;
  var minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      if (!(r > 245 && g > 245 && b > 245)) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  const cropPad = 4;
  minX = (minX - cropPad).clamp(0, src.width - 1);
  minY = (minY - cropPad).clamp(0, src.height - 1);
  maxX = (maxX + cropPad).clamp(0, src.width - 1);
  maxY = (maxY + cropPad).clamp(0, src.height - 1);
  final cropped = copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );

  const size = 1024;
  const fraction = 0.48;
  final target = (size * fraction).round();
  final scale = target / (cropped.width > cropped.height ? cropped.width : cropped.height);
  final nw = (cropped.width * scale).round();
  final nh = (cropped.height * scale).round();
  final mark = copyResize(
    cropped,
    width: nw,
    height: nh,
    interpolation: Interpolation.cubic,
  );

  final canvas = Image(width: size, height: size);
  fill(canvas, color: ColorRgb8(255, 255, 255));
  compositeImage(canvas, mark, dstX: (size - nw) ~/ 2, dstY: (size - nh) ~/ 2);

  File('assets/app_icon.png').writeAsBytesSync(encodePng(canvas));
  stdout.writeln('Wrote assets/app_icon.png mark=${nw}x$nh (~${(100 * (nw > nh ? nw : nh) / size).round()}%)');
}
