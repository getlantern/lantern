import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class AppDialog {
  static void showLanternProDialog({
    required BuildContext context,
    String? label,
    OnPressed? onPressed,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          // backgroundColor and shape come from dialogTheme in app_theme.dart
          contentPadding: EdgeInsets.symmetric(horizontal: defaultSize),
          actionsPadding: EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 24),
              LanternRoundedLogo(height: 45),
              SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: size.width * 0.7,
                  height: 40,
                  child: AutoSizeText(
                    'welcome_to_lantern_pro'.i18n,
                    style: textTheme.headlineMedium,
                    maxLines: 1,
                    minFontSize: 20,
                    maxFontSize: 24,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SizedBox(height: defaultSize),
              Text(
                'lantern_pro_description'.i18n,
                style: textTheme.bodyMedium?.copyWith(
                  height: 23 / 16,
                ),
              ),
            ],
          ),
          actions: [
            AppTextButton(
              label: label ?? 'continue'.i18n,
              onPressed: () {
                appRouter.maybePop();
                Future.delayed(
                  const Duration(milliseconds: 400),
                  () {
                    onPressed?.call();
                  },
                );
              },
            )
          ],
        );
      },
    );
  }

  static void customDialog({
    required BuildContext context,
    required Widget content,
    required List<Widget> action,
    EdgeInsetsGeometry? actionPadding,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowAlignment: OverflowBarAlignment.end,
          // backgroundColor and shape come from dialogTheme in app_theme.dart
          contentPadding: EdgeInsets.symmetric(horizontal: size24),
          actionsPadding: actionPadding ??
              EdgeInsets.only(
                  top: defaultSize,
                  bottom: defaultSize,
                  left: defaultSize,
                  right: defaultSize),
          content: content,
          actions: action,
        );
      },
    );
  }

  static void errorDialog({
    required BuildContext context,
    required String title,
    required String content,
    String? action,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          // backgroundColor and shape come from dialogTheme in app_theme.dart
          contentPadding: EdgeInsets.symmetric(horizontal: defaultSize),
          actionsPadding: EdgeInsets.only(
              top: defaultSize,
              bottom: defaultSize,
              left: defaultSize,
              right: defaultSize),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(height: defaultSize),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            AppTextButton(
              label: action ?? 'ok'.i18n,
              onPressed: () {
                appRouter.maybePop();
              },
            )
          ],
        );
      },
    );
  }

  static void dialog({
    required BuildContext context,
    required String title,
    required String content,
    String? action,
    OnPressed? onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          // backgroundColor and shape come from dialogTheme in app_theme.dart
          contentPadding: EdgeInsets.symmetric(horizontal: defaultSize),
          actionsPadding: EdgeInsets.only(
              top: defaultSize,
              bottom: defaultSize,
              left: defaultSize,
              right: defaultSize),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(height: defaultSize),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            AppTextButton(
              label: action ?? 'ok'.i18n,
              onPressed: onPressed ??
                  () {
                    appRouter.maybePop();
                  },
            )
          ],
        );
      },
    );
  }
}
