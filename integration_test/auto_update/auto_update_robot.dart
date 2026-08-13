import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';

String get autoUpdateHandoffPath {
  if (Platform.isMacOS) {
    return '/Users/Shared/Lantern/E2E/auto-update-handoff.json';
  }
  if (Platform.isWindows) {
    final programData = Platform.environment['ProgramData'];
    if (programData == null || programData.isEmpty) {
      throw StateError('ProgramData is unavailable for the update handoff');
    }
    return '$programData\\Lantern\\E2E\\auto-update-handoff.json';
  }
  throw UnsupportedError('Auto-update handoff is desktop-only');
}

/// Drives Lantern up to the native Sparkle boundary.
class AutoUpdateRobot {
  AutoUpdateRobot(this.tester) : app = AppRobot(tester);

  final WidgetTester tester;
  final AppRobot app;

  final Finder checkForUpdates = find.byKey(
    const Key('setting.check_for_updates_tile'),
  );

  Future<void> triggerUpdateCheck() async {
    e2eLog('Opening Settings for the auto-update smoke');
    await app.openSettings();
    await WidgetWaitUtils.waitForFinder(
      tester,
      checkForUpdates,
      timeout: const Duration(seconds: 30),
      reason:
          'Check for Updates did not appear. '
          'Visible keys: ${app.visibleKeys().join(', ')}',
    );
    await tester.ensureVisible(checkForUpdates);
    await _captureScreenshot('auto-update-before');

    e2eLog('Triggering Check for Updates');
    await app.tap(checkForUpdates, name: 'Check for Updates', settle: false);
  }

  Future<void> _captureScreenshot(String name) async {
    try {
      final renderView = tester.binding.renderViews.first;
      final layer = renderView.debugLayer;
      if (layer is! OffsetLayer) {
        e2eLog('Screenshot $name skipped: root layer is not capturable');
        return;
      }
      final image = await layer.toImage(renderView.paintBounds);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          e2eLog('Screenshot $name skipped: no image data');
          return;
        }
        final directory = Directory(
          '${await AppStorageUtils.getAppLogDirectory()}/screenshots',
        );
        await directory.create(recursive: true);
        final file = File('${directory.path}/$name.png');
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
        e2eLog('Screenshot saved: ${file.path}');
      } finally {
        image.dispose();
      }
    } catch (error) {
      e2eLog('Screenshot $name failed: $error');
    }
  }

  Future<void> writeNativeHandoff() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final handoff = File(autoUpdateHandoffPath);
    final payload = {
      'pid': pid,
      'display_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await handoff.parent.create(recursive: true);
    await handoff.writeAsString('${jsonEncode(payload)}\n', flush: true);
    e2eLog('Native updater handoff ready at ${handoff.path}');
  }
}
