import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_buttons.dart';

import '../common/app_colors.dart';
import '../common/app_text_styles.dart';

class AppRichText extends StatelessWidget {
  final String texts;
  final String boldTexts;

  final bool boldUnderline;
  final OnPressed? boldOnPressed;
  final Color? boldColor;

  const AppRichText({
    super.key,
    required this.texts,
    required this.boldTexts,
    this.boldOnPressed,
    this.boldUnderline = false,
    this.boldColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return RichText(
      text: TextSpan(
        text: texts,
        style: textTheme.labelLarge!.copyWith(
          color: AppColors.gray8,

        ),
        children: [
          TextSpan(
            text: boldTexts,
            style:  textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.bold,
              color: boldColor ?? AppColors.gray8,
              decoration: boldUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
            recognizer: TapGestureRecognizer()..onTap = boldOnPressed,
          )
        ],
      ),
    );
  }
}
