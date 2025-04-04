import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_buttons.dart';

import '../common/app_colors.dart';

class AppRichText extends StatelessWidget {
  final String texts;
  final String boldTexts;

  final bool boldUnderline;
  final OnPressed? boldOnPressed;

  const AppRichText({
    super.key,
    required this.texts,
    required this.boldTexts,
    this.boldOnPressed,
    this.boldUnderline=false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return RichText(
      text: TextSpan(
        text: texts,
        style: textTheme.bodyMedium,
        children: [
          TextSpan(
            text: boldTexts,
            style: textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.gray9,
              decoration: boldUnderline?TextDecoration.underline:TextDecoration.none,
            ),
            recognizer: TapGestureRecognizer()..onTap = boldOnPressed,
          )
        ],
      ),
    );
  }
}
