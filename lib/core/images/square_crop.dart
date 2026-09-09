import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';

/// Pixel tolerance matching web `isNearlySquareImage` (rounding after compress).
const int kSquareTolerancePx = 2;

bool isNearlySquareDimensions(int width, int height, {int tolerancePx = kSquareTolerancePx}) {
  return (width - height).abs() <= tolerancePx;
}

/// True when width and height match within a few pixels.
Future<bool> isNearlySquareFile(File file, {int tolerancePx = kSquareTolerancePx}) async {
  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) return false;
  return isNearlySquareDimensions(image.width, image.height, tolerancePx: tolerancePx);
}

/// True when a remote image is nearly square (existing covers on edit).
Future<bool> isNearlySquareUrl(String url, {int tolerancePx = kSquareTolerancePx}) async {
  final response = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final data = response.data;
  if (data == null || data.isEmpty) return false;
  final bytes = data is Uint8List ? data : Uint8List.fromList(data);
  final image = img.decodeImage(bytes);
  if (image == null) return false;
  return isNearlySquareDimensions(image.width, image.height, tolerancePx: tolerancePx);
}

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
