// Extension for showing error SnackBars.
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '../common/app_dimens.dart' show defaultPadding, tvSafeMarginV;
import '../utils/platform_utils.dart';

/// In the TV shell the snackbar sits inside the bottom safe margin and has
/// no close button, which would take D-pad focus; null elsewhere.
EdgeInsets? _tvSnackBarMargin() => PlatformUtils.tvShellEnabled
    ? const EdgeInsets.fromLTRB(16, 0, 16, tvSafeMarginV)
    : null;

bool _snackBarCloseButton(bool closeButton) =>
    closeButton && !PlatformUtils.tvShellEnabled;

extension SnackBarExtensions on BuildContext {
  void showSnackBarError(String message, {bool closeButton = false}) {
    final textTheme = Theme.of(this).textTheme.bodyMedium;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        padding: defaultPadding,
        margin: _tvSnackBarMargin(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: bgSnackbarError,
        showCloseIcon: _snackBarCloseButton(closeButton),
        closeIconColor: textInverse,
        content: Text(
          message,
          style: textTheme!.copyWith(
            color: textInverse,
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
        margin: _tvSnackBarMargin(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: bgSnackbar,
        showCloseIcon: _snackBarCloseButton(closeButton),
        closeIconColor: textInverse,
        content: Text(
          message,
          style: textTheme!.copyWith(
            color: textInverse,
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
