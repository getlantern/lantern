// Extension for showing error SnackBars.
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '../common/app_dimens.dart' show defaultPadding;

extension SnackBarExtensions on BuildContext {
  void showSnackBarError(String message, {bool closeButton = false}) {
    final textTheme = Theme.of(this).textTheme.bodyMedium;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        padding: defaultPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.red7,
        showCloseIcon: closeButton,
        closeIconColor: AppColors.white,
        content: Text(
          message,
          style: textTheme!.copyWith(
            color: AppColors.white,
          ),
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  void showSnackBar(String message, {bool closeButton = false}) {
    final textTheme = Theme.of(this).textTheme.bodyMedium;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        padding: defaultPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.blue9,
        showCloseIcon: closeButton,
        closeIconColor: AppColors.white,
        content: Text(
          message,
          style: textTheme!.copyWith(
            color: AppColors.white,
          ),
        ),
        duration: Duration(seconds: 5),
      ),
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
