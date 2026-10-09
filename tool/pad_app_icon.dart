import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/shared/branding/brand_mark_paths.dart';

/// Exports the actual vector curves through Flutter's native graphics engine.
/// Run from the project root: flutter test tool/pad_app_icon.dart.
void main() {
  test('Export shared brand assets', () async {
    await _write('assets/app_icon.png', 1024, launcher: true);
    await _write('assets/splash_logo.png', 1024);
    await _write('assets/logo.png', 1024, background: 0xFFF8F6FA);

    const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = jsonDecode(
      File('$iosDirectory/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final written = <String>{};
    for (final entry in contents['images'] as List) {
      final image = entry as Map<String, dynamic>;
      final filename = image['filename'] as String;
      if (!written.add(filename)) continue;
      final points = double.parse((image['size'] as String).split('x').first);
      final density = double.parse(
        (image['scale'] as String).replaceAll('x', ''),
      );
      await _write(
        '$iosDirectory/$filename',
        (points * density).round(),
        launcher: true,
      );
    }
    for (var density = 1; density <= 3; density++) {
      final suffix = density == 1 ? '' : '@${density}x';
      await _write(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
        168 * density,
      );
    }

    const densities = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    for (final entry in densities.entries) {
      final directory = 'android/app/src/main/res/mipmap-${entry.key}';
      await _write(
        '$directory/ic_launcher.png',
        (48 * entry.value).round(),
        launcher: true,
      );
      // The inner 72dp of a 108dp adaptive layer matches iOS's visible size.
      await _write(
        '$directory/ic_launcher_foreground.png',
        (108 * entry.value).round(),
        launcher: true,
        viewport: (72 * entry.value).round(),
      );
      await _write(
        'android/app/src/main/res/drawable-${entry.key}/splash_logo.png',
        (192 * entry.value).round(),
      );
    }
    for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
      await _write(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
        size,
        launcher: true,
      );
    }
    await _write('web/favicon.png', 32, launcher: true);
    for (final size in [192, 512]) {
      for (final prefix in ['Icon', 'Icon-maskable']) {
        await _write('web/icons/$prefix-$size.png', size, launcher: true);
      }
    }
  });
}

Future<void> _write(
  String path,
  int size, {
  bool launcher = false,
  int background = 0xFFFFFFFF,
  int? viewport,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(ui.Color(background), ui.BlendMode.src);
  // Export the same Bezier paths used by the app; no polygon approximation.
  if (launcher) {
    final scale = (viewport ?? size) * 0.72 / 617;
    canvas.translate(size / 2 - 512.5 * scale, size / 2 - 510.5 * scale);
    canvas.scale(scale);
  } else {
    canvas.scale(size / 1024);
  }
  paintBrandMark(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(
    bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  image.dispose();
  picture.dispose();
}
