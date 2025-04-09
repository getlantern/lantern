// Extension for showing error SnackBars.
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path/path.dart';

extension SnackBarExtensions on BuildContext {
  void showSnackBarError(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}


extension DialogExtensions on BuildContext {

  void showLoadingDialog() {
   loaderOverlay.show();
  }

  void hideLoadingDialog() {
    loaderOverlay.hide();
  }

}
