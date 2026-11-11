import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/action_mode/auto_enable_mode.dart';

/// "You're now [name]'s Personal Proxy": the Action Mode informational
/// dialog with the Auto-enable Action Mode row. Checking the box turns
/// Action Mode on now and sets Auto-enable; Done only closes. Shown on the
/// root navigator, so it outlives the Become a Personal Proxy screen.
Future<void> showHelperApprovedDialog(
  BuildContext context, {
  required String name,
}) => AppDialog.show(
  context: context,
  scrollable: true,
  // AppImage tints SVGs with the theme's icon colour unless told the colour.
  header: Center(
    child: AppImage(
      path: AppImagePaths.greenCheck,
      height: 48,
      color: context.statusSuccessBgDot,
    ),
  ),
  centeredTitle: true,
  title: 'help_friend_success_title'.i18n.fill([name]),
  body: 'help_friend_success_body'.i18n.fill([name]),
  content: const Padding(
    key: Key('help_friend.approved'),
    padding: EdgeInsets.only(top: 16),
    child: ActionModeAutoEnable(
      key: Key('help_friend.keep_on'),
      card: false,
      startNow: true,
    ),
  ),
  primaryLabel: 'help_friend_done'.i18n,
);
