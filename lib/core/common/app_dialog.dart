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
          backgroundColor: AppColors.gray3,
          contentPadding: EdgeInsets.symmetric(horizontal: defaultSize),
          actionsPadding: EdgeInsets.only(
              top: defaultSize,
              bottom: defaultSize,
              left: defaultSize,
              right: defaultSize),
          // contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 24),
              LanternRoundedLogo(
                height: 45
              ),
              SizedBox(height: defaultSize),
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
                style: textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            AppTextButton(
              label: label ?? 'continue'.i18n,
              onPressed: () {
                appRouter.maybePop();
                Future.delayed(
                  const Duration(milliseconds: 500),
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
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.gray3,
          contentPadding: EdgeInsets.symmetric(horizontal: defaultSize),
          actionsPadding: EdgeInsets.only(
              top: defaultSize,
              bottom: defaultSize,
              left: defaultSize,
              right: defaultSize),
          // contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
    String action = 'ok',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.gray3,
          contentPadding: EdgeInsets.symmetric(horizontal: defaultSize),
          actionsPadding: EdgeInsets.only(
              top: defaultSize,
              bottom: defaultSize,
              left: defaultSize,
              right: defaultSize),
          // contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
              label: action,
              onPressed: () {
                appRouter.maybePop();
              },
            )
          ],
        );
      },
    );
  }
}
