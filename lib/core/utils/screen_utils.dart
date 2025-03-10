import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';

extension DevicePreviewExtensions on BuildContext {
  bool get isSmallDevice {
    final devicePreview = MediaQuery.of(this).size;
    return devicePreview.width <= 360 && devicePreview.height <= 640;
  }
}

const defaultAnimationDuration = Duration(milliseconds: 1000);

void showSnackbar({
  required BuildContext context,
  required dynamic content,
  Duration duration = defaultAnimationDuration,
  SnackBarAction? action,
}) {
  final snackBar = SnackBar(
    content: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: content is String
              ? Text(
                  content,
                  style: AppTestStyles.bodyMedium,
                  textAlign: TextAlign.start,
                )
              : content,
        ),
      ],
    ),
    action: action,
    backgroundColor: Colors.black,
    duration: duration,
    margin: const EdgeInsetsDirectional.symmetric(vertical: 16, horizontal: 8),
    padding:
        const EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
    behavior: SnackBarBehavior.floating,
    elevation: 1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8.0)),
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
