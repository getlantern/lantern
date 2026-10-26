import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';

/// Confirms browser bypasses and explains other app bypasses on first use.
Future<bool> confirmAppBypass(BuildContext context, AppData app) async {
  final storage = sl<LocalStorageService>();
  if (!app.isBrowser && storage.hasSeenBypassAppDialog) return true;

  var confirmed = false;
  final navigator = Navigator.of(context, rootNavigator: true);
  void confirm() {
    confirmed = context.mounted;
    navigator.pop();
  }

  await AppDialog.show(
    context: context,
    header: Center(
      child: AppImage(
        path: app.isBrowser ? AppImagePaths.warning : AppImagePaths.info,
        height: app.isBrowser ? 45 : 40,
      ),
    ),
    centeredTitle: true,
    title:
        (app.isBrowser
                ? 'bypass_browser_warning_title'
                : 'bypass_app_first_time_title')
            .i18n
            .fill([app.name]),
    body:
        (app.isBrowser
                ? 'bypass_browser_warning_body'
                : 'bypass_app_first_time_body')
            .i18n
            .fill([app.name]),
    primaryLabel: (app.isBrowser ? 'cancel' : 'add').i18n,
    dismissOnPrimary: app.isBrowser,
    onPrimaryPressed: app.isBrowser ? null : confirm,
    secondaryLabel: (app.isBrowser ? 'add_anyway' : 'cancel').i18n,
    dismissOnSecondary: !app.isBrowser,
    onSecondaryPressed: app.isBrowser ? confirm : null,
  );
  if (!confirmed || !context.mounted) return false;
  if (!app.isBrowser) await storage.markBypassAppDialogSeen();
  return context.mounted;
}
