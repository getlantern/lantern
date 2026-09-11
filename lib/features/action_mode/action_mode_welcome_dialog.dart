import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

/// First-visit Unbounded welcome popup
/// (figma.com/design/hNlyYToB5TnX9SDBFDYJTq?node-id=7377-28803). Any dismissal
/// marks it seen; the info icon in the tab header re-opens it.
void showActionModeWelcomeDialog(BuildContext context, WidgetRef ref) {
  // Read up front: the calling widget may be disposed by the time the dialog
  // closes, but the notifier outlives it.
  final appSetting = ref.read(appSettingProvider.notifier);
  AppDialog.show(
    context: context,
    barrierDismissible: true,
    scrollable: true,
    header: const Center(
      child: AppImage(path: AppImagePaths.actionMode, width: 48, height: 48),
    ),
    centeredTitle: true,
    title: 'unbounded_welcome_title'.i18n,
    body: [
      'unbounded_welcome_body_1'.i18n,
      'unbounded_welcome_body_2'.i18n,
      'unbounded_welcome_body_3'.i18n,
    ].join('\n\n'),
    primaryLabel: 'got_it'.i18n,
    secondaryLabel: 'learn_more'.i18n,
    secondaryIcon: AppImagePaths.outsideBrowser,
    dismissOnSecondary: false,
    onSecondaryPressed: () => UrlUtils.openUrl(AppUrls.unbounded),
  ).whenComplete(() {
    appSetting.setUnboundedWelcomeSeen(true);
  });
}
