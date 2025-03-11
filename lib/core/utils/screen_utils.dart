import 'package:flutter/material.dart';

extension DevicePreviewExtensions on BuildContext {
  bool get isSmallDevice {
    final devicePreview = MediaQuery.of(this).size;
    return devicePreview.width <= 380 && devicePreview.height <= 680;
  }
}
