import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class AppDialog {
  static Future<void> show({
    required BuildContext context,
    Widget? header,
    String? title,
    String? body,
    Widget? content,
    required String primaryLabel,
    OnPressed? onPrimaryPressed,
    String? secondaryLabel,
    OnPressed? onSecondaryPressed,
    bool centered = false,
    bool barrierDismissible = false,
    // When false the primary callback is responsible for dismissing the
    // dialog itself (e.g. vpnConflictDialog callers already pop).
    bool dismissOnPrimary = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return AlertDialog(
          // backgroundColor and shape come from dialogTheme in app_theme.dart
          contentPadding: EdgeInsets.all(24),
          // Buttons live inside content (not `actions`) so they can stretch
          // full-width and stack vertically per the design.
          content: SizedBox(
            // AlertDialog sizes to the content's intrinsic width, which
            // collapses custom content. maxFinite makes it fill instead; the
            // min/max width bounds come from dialogTheme (Material 280–560dp).
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.stretch,
              children: <Widget>[
                if (header != null) ...[header, SizedBox(height: size24)],
                if (title != null) ...[
                  Text(
                    title,
                    style: textTheme.headlineMedium,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                  ),
                  SizedBox(height: 8),
                ],
                if (body != null)
                  Text(
                    body,
                    style: textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                      height: 23 / 16,
                    ),
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                  ),
                ?content,
                SizedBox(height: size24),
                PrimaryButton(
                  label: primaryLabel,
                  onPressed: () {
                    if (!dismissOnPrimary) {
                      onPrimaryPressed?.call();
                      return;
                    }
                    // Pop via the dialog's own navigator so this also works
                    // when shown outside appRouter (e.g. widget tests).
                    Navigator.of(context).pop();
                    if (onPrimaryPressed != null) {
                      Future.delayed(
                        const Duration(milliseconds: 400),
                        onPrimaryPressed,
                      );
                    }
                  },
                ),
                if (secondaryLabel != null) ...[
                  SizedBox(height: 12),
                  SecondaryButton(
                    label: secondaryLabel,
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onSecondaryPressed != null) {
                        Future.delayed(
                          const Duration(milliseconds: 400),
                          onSecondaryPressed,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static void showLanternProDialog({
    required BuildContext context,
    String? label,
    OnPressed? onPressed,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    show(
      context: context,
      centered: true,
      header: LanternRoundedLogo(height: 45),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
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
          SizedBox(height: defaultSize),
          Text(
            'lantern_pro_description'.i18n,
            style: textTheme.bodyMedium?.copyWith(height: 23 / 16),
          ),
        ],
      ),
      primaryLabel: label ?? 'continue'.i18n,
      onPrimaryPressed: onPressed,
    );
  }

  static void purchaseRestoredDialog({
    required BuildContext context,
    OnPressed? onPressed,
  }) {
    show(
      context: context,
      header: Center(
        child: AppImage(
          path: AppImagePaths.greenCheck,
          height: 50,
          useThemeColor: false,
        ),
      ),
      title: 'purchase_restored_title'.i18n,
      body: 'purchase_restored_description'.i18n,
      primaryLabel: 'continue'.i18n,
      onPrimaryPressed: onPressed,
    );
  }

  static void noPurchaseFoundDialog({
    required BuildContext context,
    OnPressed? onPressed,
  }) {
    final body = Platform.isIOS
        ? 'no_purchase_found_body_ios'.i18n
        : 'no_purchase_found_body_android'.i18n;
    show(
      context: context,
      header: Center(child: AppImage(path: AppImagePaths.info, height: 40)),
      title: 'no_purchase_found_title'.i18n,
      body: body,
      primaryLabel: 'ok'.i18n,
      onPrimaryPressed: onPressed,
    );
  }

  static Future<void> customDialog({
    required BuildContext context,
    required Widget content,
    required List<Widget> action,
    EdgeInsetsGeometry? actionPadding,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          // backgroundColor and shape come from dialogTheme in app_theme.dart
          // Callers add their own top spacing inside content.
          contentPadding: EdgeInsets.symmetric(horizontal: size24),
          actionsPadding: actionPadding ?? EdgeInsets.all(size24),
          // AlertDialog sizes to the content's intrinsic width, which collapses
          // this custom content. maxFinite makes it fill instead; the min/max
          // width bounds come from dialogTheme (Material 280–560dp).
          content: SizedBox(width: double.maxFinite, child: content),
          // Actions stack vertically full-width per the design instead of the
          // default trailing OverflowBar row.
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < action.length; i++) ...[
                  if (i > 0) SizedBox(height: defaultSize),
                  action[i],
                ],
              ],
            ),
          ],
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
    show(
      context: context,
      title: title,
      body: content,
      primaryLabel: action ?? 'ok'.i18n,
    );
  }

  static void vpnConflictDialog({
    required BuildContext context,
    required VoidCallback onConnectAnyway,
  }) {
    show(
      context: context,
      title: 'vpn_conflict_title'.i18n,
      body: 'vpn_conflict_body'.i18n,
      primaryLabel: 'vpn_conflict_connect_anyway'.i18n,
      onPrimaryPressed: onConnectAnyway,
      // Callers pop the dialog inside onConnectAnyway themselves.
      dismissOnPrimary: false,
      secondaryLabel: 'vpn_conflict_dismiss'.i18n,
    );
  }

  static void dialog({
    required BuildContext context,
    required String title,
    required String content,
    String? action,
    OnPressed? onPressed,
  }) {
    show(
      context: context,
      title: title,
      body: content,
      primaryLabel: action ?? 'ok'.i18n,
      onPrimaryPressed: onPressed,
      // Preserve the original dialog contract: when a callback is supplied,
      // it is responsible for dismissing or replacing the current route.
      dismissOnPrimary: onPressed == null,
    );
  }
}
