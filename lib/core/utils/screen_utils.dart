import 'package:flutter/material.dart';

extension DevicePreviewExtensions on BuildContext {
  bool get isSmallDevice {
    final devicePreview = MediaQuery.of(this).size;
    return devicePreview.width <= 360 && devicePreview.height <= 640;
  }
}
