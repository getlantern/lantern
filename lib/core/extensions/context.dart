// Extension for showing error SnackBars.
import 'package:flutter/material.dart';

extension SnackBarExtensions on BuildContext {
  void showSnackBarError(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
