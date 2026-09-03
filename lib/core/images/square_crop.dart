import 'dart:io';
import 'dart:ui' show Color;

import 'package:image_cropper/image_cropper.dart';

/// Opens a square-only crop UI. Returns null if the user cancels.
Future<File?> cropSquareImage(File file) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: file.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop to square',
        toolbarColor: const Color(0xFFF0D7FF),
        toolbarWidgetColor: const Color(0xFF3D2F4A),
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
      IOSUiSettings(
        title: 'Crop to square',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}
