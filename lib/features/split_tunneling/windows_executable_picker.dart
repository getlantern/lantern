import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';

final windowsExecutablePickerProvider = Provider<Future<String?> Function()>(
  (ref) => _pickExecutable,
);

Future<String?> _pickExecutable() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Windows executable', extensions: ['exe']),
    ],
  );
  if (file == null) return null;
  if (!isWindowsExecutablePath(file.path) ||
      await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
    throw const FormatException('Select a local Windows executable');
  }
  return file.path;
}

class WindowsExecutablePicker extends HookConsumerWidget {
  const WindowsExecutablePicker({required this.confirmBypass, super.key});

  final Future<bool> Function(BuildContext context, AppData app) confirmBypass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final apps = ref.watch(splitTunnelingAppsProvider);
    // Keep discovery active while the file dialog is open.
    ref.watch(appsDataProvider);

    Future<void> pickExecutable() async {
      if (busy.value) return;
      busy.value = true;
      try {
        final path = await ref.read(windowsExecutablePickerProvider)();
        if (path == null || !context.mounted) return;
        final installed = await ref.read(appsDataProvider.future);
        if (!context.mounted) return;
        final app = windowsEnabledApps(installed, [path]).single;
        if (!await confirmBypass(context, app) || !context.mounted) return;
        final failure = await ref
            .read(splitTunnelingAppsProvider.notifier)
            .addExecutable(path);
        if (failure != null && context.mounted) {
          context.showSnackBarError(failure.localizedErrorMessage);
        }
      } catch (error, stackTrace) {
        appLogger.error('Unable to add Windows executable', error, stackTrace);
        if (context.mounted) {
          context.showSnackBarError('unable_to_add_executable'.i18n);
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return AppTextButton(
      key: const ValueKey('add-windows-executable'),
      label: 'add_executable'.i18n,
      onPressed: !busy.value && !apps.isLoading && !apps.hasError
          ? pickExecutable
          : null,
    );
  }
}
