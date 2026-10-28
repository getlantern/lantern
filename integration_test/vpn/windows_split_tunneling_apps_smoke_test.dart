import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';
import 'package:lantern/features/split_tunneling/windows_executable_picker.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/main.dart' as app;
import 'package:path/path.dart' as p;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';
import 'split_tunneling_smoke_helpers.dart';
import 'vpn_smoke_helpers.dart';

// Only the OS file dialog is replaced. Validation, persistence and routing all
// go through the same code and Windows service used by the installed app.
class _ExecutablePicker extends FileSelectorPlatform {
  String? nextPath;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    expect(acceptedTypeGroups?.single.extensions, ['exe']);
    final path = nextPath;
    nextPath = null;
    expect(path, isNotNull, reason: 'Unexpected executable picker request');
    return XFile(path!);
  }
}

T _require<T>(Either<Failure, T> result, String operation) =>
    requireSplitTunnelResult(result, operation);

Finder _appRow(String path, {bool selected = true}) => find.byKey(
  ValueKey(
    'split-tunnel-app:${selected ? 'processPath:' : ''}${windowsAppPathId(path)}',
  ),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await WidgetWaitUtils.waitForFinder(
    tester,
    finder,
    timeout: const Duration(seconds: 20),
  );
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
  }
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder.hitTestable());
  await tester.pump(const Duration(milliseconds: 200));
}

Future<String> _addExecutable(
  WidgetTester tester,
  _ExecutablePicker picker,
  String path, {
  bool bypass = true,
}) async {
  final service = sl<LanternService>();
  Future<List<String>> readPaths() async => _require(
    await service.getSplitTunnelItems(SplitTunnelFilterType.processPath),
    'Read executable rules',
  );
  final before = (await readPaths()).toSet();
  final button = find.byKey(const ValueKey('add-windows-executable'));
  await WidgetWaitUtils.waitForFinder(
    tester,
    button,
    timeout: const Duration(seconds: 20),
  );
  final container = ProviderScope.containerOf(tester.element(button));
  await container.read(splitTunnelingAppsProvider.future);
  picker.nextPath = path;
  await _tap(tester, button);
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    final confirmation = find.ancestor(
      of: find.text('bypass_app_first_time_title'.i18n),
      matching: find.byType(AlertDialog),
    );
    if (confirmation.evaluate().isNotEmpty) {
      expect(
        bypass,
        isTrue,
        reason: 'Include only must not show a bypass warning',
      );
      await _tap(
        tester,
        find.descendant(
          of: confirmation,
          matching: find.widgetWithText(PrimaryButton, 'add'.i18n),
        ),
      );
      continue;
    }
    final added = (await readPaths()).toSet().difference(before);
    if (added.isNotEmpty) {
      expect(added, hasLength(1));
      final canonicalPath = added.single;
      try {
        await revealBypassedApp(tester, _appRow(canonicalPath));
      } on TestFailure {
        final state = container.read(splitTunnelingAppsProvider);
        final selected = state.value?.any(
          (app) =>
              windowsAppPathId(app.appPath) == windowsAppPathId(canonicalPath),
        );
        debugPrint(
          'Missing executable row: selected=$selected, '
          'loading=${state.isLoading}, error=${state.hasError}',
        );
        rethrow;
      }
      return canonicalPath;
    }
  }
  fail('Manually selected executable was not saved');
}

Future<void> _expectRegisteredApps(
  WidgetTester tester,
  ProviderContainer container,
  Map<String, String> executables,
) async {
  final discovered = await container
      .read(appsDataProvider.future)
      .timeout(const Duration(seconds: 60));
  final saved = _require(
    await sl<LanternService>().getSplitTunnelItems(
      SplitTunnelFilterType.processPath,
    ),
    'Read executable rules before discovery assertions',
  ).map(windowsAppPathId).toSet();
  for (final entry in executables.entries) {
    final path = windowsAppPathId(
      _windowsPathName(entry.value, 'GetLongPathNameW'),
    );
    final matches = discovered.where(
      (app) => windowsAppPathId(app.appPath) == path,
    );
    expect(
      matches,
      isNotEmpty,
      reason: '${entry.key} was not discovered without manual selection',
    );
    expect(
      saved,
      isNot(contains(path)),
      reason: '${entry.key} must not come from a saved bypass rule',
    );
    await expectInstalledApp(
      tester,
      query: matches.first.name,
      row: _appRow(path, selected: false),
    );
    debugPrint('Discovered ${entry.key} in Installed Apps: $path');
  }
}

Future<String?> _probeIP(String executable, {String? child}) async {
  final process = await Process.start(
    executable,
    child == null ? const [] : ['--child', child],
    runInShell: false,
  );
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.drain<void>();
  final completed = Future.wait<Object?>([
    process.exitCode,
    output,
    errors.then((_) => null),
  ]);
  try {
    final result = await completed.timeout(const Duration(seconds: 20));
    final exitCode = result[0] as int;
    final ip = (result[1] as String).trim();
    return exitCode == 0 &&
            InternetAddress.tryParse(ip)?.type == InternetAddressType.IPv4
        ? ip
        : null;
  } on TimeoutException {
    // Kill this fixture's entire process tree, never processes found by name.
    await Process.run('taskkill.exe', [
      '/PID',
      '${process.pid}',
      '/T',
      '/F',
    ]).timeout(const Duration(seconds: 5));
    await completed.timeout(const Duration(seconds: 5));
    return null;
  } finally {
    process.kill();
  }
}

Future<String> _waitForIP(
  WidgetTester tester,
  String executable, {
  String? child,
  required bool Function(String) accepts,
  required String reason,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 75));
  while (DateTime.now().isBefore(deadline)) {
    final ip = await _probeIP(executable, child: child);
    if (ip != null && accepts(ip)) return ip;
    await tester.pump(const Duration(seconds: 2));
  }
  fail(reason);
}

Future<void> _expectPersistedRule(
  String executable, {
  required bool present,
}) async {
  expect(
    await waitForSplitTunnelRule(
      field: 'process_path',
      value: executable,
      present: present,
      timeout: const Duration(seconds: 20),
    ),
    isTrue,
    reason: 'Exact process-path rule did not match persisted configuration',
  );
}

Future<Set<String>> _persistedAliasRules() async {
  final snapshot = await readSplitTunnelConfigFromDisk();
  expect(snapshot, isNotNull);
  final rules = splitTunnelRuleValues(snapshot!.value, 'process_path_regex');
  expect(rules, isNotNull);
  return rules!;
}

String _windowsPathName(String path, String function) {
  final resolve = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Uint32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
        int Function(Pointer<Utf16>, Pointer<Utf16>, int)
      >(function);
  const capacity = 32768;
  final input = path.toNativeUtf16();
  final output = calloc<Uint16>(capacity).cast<Utf16>();
  try {
    final length = resolve(input, output, capacity);
    expect(length, allOf(greaterThan(0), lessThan(capacity)));
    return output.toDartString(length: length);
  } finally {
    calloc.free(input);
    calloc.free(output);
  }
}

Future<void> _updateLegacyRule(
  String cli,
  String operation,
  String path,
) async {
  final process = await Process.start(cli, [
    'split-tunnel',
    operation,
    '--type',
    'process-path',
    '--value',
    path,
  ], runInShell: false);
  try {
    final result = await Future.wait<Object>([
      process.exitCode,
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.transform(utf8.decoder).join(),
    ]).timeout(const Duration(seconds: 20));
    expect(
      result[0],
      0,
      reason: 'Legacy rule $operation failed: ${result[1]} ${result[2]}',
    );
  } finally {
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 5));
  }
}

Future<void> _captureScreenshot(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment(
    'SPLIT_TUNNEL_SCREENSHOT_DIR',
    defaultValue: 'build/windows-split-tunnel-smoke',
  );
  await tester.pump(const Duration(milliseconds: 300));
  await AppRobot(tester).captureScreenshot(name, outputDirectory: directory);
  expect(
    await File(p.join(directory, '$name.png')).exists(),
    isTrue,
    reason: 'Windows split-tunneling screenshot was not captured',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows executable selections route both modes and clear during search',
    (tester) async {
      expect(Platform.isWindows, isTrue);
      const probePath = String.fromEnvironment('SPLIT_TUNNEL_PROBE');
      expect(
        probePath,
        isNotEmpty,
        reason: 'Run through windows_smoke_suite.ps1',
      );
      expect(await File(probePath).exists(), isTrue);
      const cliPath = String.fromEnvironment('SPLIT_TUNNEL_CLI');
      expect(
        cliPath,
        isNotEmpty,
        reason: 'Run through windows_smoke_suite.ps1',
      );
      expect(await File(cliPath).exists(), isTrue);

      const registeredExecutables = {
        'Start Menu launcher': String.fromEnvironment(
          'SPLIT_TUNNEL_REGISTERED_LAUNCHER',
        ),
        'App Paths game': String.fromEnvironment(
          'SPLIT_TUNNEL_REGISTERED_GAME',
        ),
      };
      for (final entry in registeredExecutables.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: '${entry.key} fixture is missing',
        );
        expect(await File(entry.value).exists(), isTrue);
      }

      final fixtures = await Directory(
        p.dirname(probePath),
      ).createTemp('Lantern split smoke ');
      addTearDown(() => fixtures.delete(recursive: true));
      Future<String> copyProbe(String directory, String name) async {
        final folder = await Directory(
          p.join(fixtures.path, directory),
        ).create();
        return (await File(probePath).copy(p.join(folder.path, name))).path;
      }

      final launcher = await copyProbe('Game Launcher', 'Launcher.exe');
      final child = await copyProbe('Game Files 遊戲', 'Game Client.exe');
      final unrelated = await copyProbe('Other Game', 'Game Client.exe');
      final childLong = _windowsPathName(child, 'GetLongPathNameW');
      final childShort = _windowsPathName(child, 'GetShortPathNameW');
      expect(
        p.windows.basename(childShort).toLowerCase(),
        isNot(p.windows.basename(childLong).toLowerCase()),
        reason: 'This smoke requires real 8.3 aliases on the fixture volume',
      );
      final childLaunches = {
        'long path': childLong,
        'short path': childShort,
        'long directory and short filename': p.windows.join(
          p.windows.dirname(childLong),
          p.windows.basename(childShort),
        ),
        'short directory and long filename': p.windows.join(
          p.windows.dirname(childShort),
          p.windows.basename(childLong),
        ),
      };
      final legacy = await copyProbe(
        'Legacy Game 遊戲',
        'Legacy Game Client.exe',
      );
      final legacyShort = _windowsPathName(legacy, 'GetShortPathNameW');
      final legacyRule = windowsAppPathId(
        _windowsPathName(legacy, 'GetLongPathNameW'),
      );
      expect(
        p.windows.basename(legacyShort).toLowerCase(),
        isNot(p.windows.basename(legacy).toLowerCase()),
        reason: 'This smoke requires real 8.3 aliases on the fixture volume',
      );
      addTearDown(() async {
        for (final path in [legacyShort, legacyRule]) {
          await _updateLegacyRule(cliPath, 'remove', path);
        }
      });

      await app.main();
      final finders = VpnSmokeFinders();
      final states = VpnStateFinders();
      await prepareVpnStartsDisconnectedForSmoke(
        tester,
        finders: finders,
        vpnStateFinders: states,
        scenario: 'app split tunneling smoke',
      );
      final container = ProviderScope.containerOf(
        tester.element(finders.homeScreen),
      );
      final service = sl<LanternService>();
      final original = _require(
        await service.getSplitTunnelState(),
        'Read split-tunnel state',
      );
      expect(original.supported, isTrue);
      final wasSmart = _require(
        await service.isSmartRoutingEnabled(),
        'Read routing mode',
      );
      addTearDown(() async {
        _require(
          await service.setRoutingMode(wasSmart),
          'Restore routing mode',
        );
      });
      addTearDown(() async {
        await restoreSplitTunnelSnapshot(service, original);
      });
      for (final path in [launcher, childLong, legacyRule]) {
        addTearDown(() async {
          _require(
            await service.removeSplitTunnelItem(
              SplitTunnelFilterType.processPath,
              path,
            ),
            'Remove fixture rule',
          );
        });
      }
      try {
        _require(await service.setRoutingMode(false), 'Enable full tunnel');
        _require(
          await service.switchSplitTunnelPolicy('include'),
          'Reset fixture selections',
        );
        _require(
          await service.switchSplitTunnelPolicy('exclude'),
          'Start in Bypass',
        );
        _require(
          await service.setSplitTunnelingEnabled(true),
          'Enable split tunneling',
        );
        expect(
          await container.read(splitTunnelProvider.notifier).refresh(),
          isNull,
        );

        final picker = _ExecutablePicker();
        final originalPicker = FileSelectorPlatform.instance;
        FileSelectorPlatform.instance = picker;
        addTearDown(() => FileSelectorPlatform.instance = originalPicker);
        final baseline = await _waitForIP(
          tester,
          launcher,
          child: child,
          accepts: (_) => true,
          reason: 'Could not get the direct baseline IP',
        );

        unawaited(appRouter.push(const AppsSplitTunneling()));
        await WidgetWaitUtils.waitForFinder(
          tester,
          find.byType(WindowsExecutablePicker),
          timeout: const Duration(seconds: 20),
        );
        await container.read(splitTunnelingAppsProvider.future);
        await _expectRegisteredApps(tester, container, registeredExecutables);
        await tester.ensureVisible(find.byType(WindowsExecutablePicker));
        await _captureScreenshot(tester, 'windows-executable-picker');
        final launcherRule = await _addExecutable(tester, picker, launcher);
        await _expectPersistedRule(launcherRule, present: true);
        appRouter.popUntilRoot();
        await tester.pump(const Duration(milliseconds: 400));

        // Seed through the daemon so Lantern has not normalized this old rule.
        await _updateLegacyRule(cliPath, 'add', legacyShort);
        await _expectPersistedRule(legacyShort, present: true);
        await _expectPersistedRule(legacyRule, present: false);
        await _tap(tester, finders.vpnToggle);
        await states.waitFor(
          tester,
          expected: [VPNStatus.connected],
          timeout: const Duration(seconds: 60),
          reason: 'VPN did not connect',
          allowVpnConflict: true,
        );
        await _expectPersistedRule(legacyShort, present: false);
        await _expectPersistedRule(legacyRule, present: true);
        await _waitForIP(
          tester,
          legacyShort,
          accepts: (ip) => ip == baseline,
          reason: 'The migrated legacy short path did not bypass the VPN',
        );

        await _waitForIP(
          tester,
          launcher,
          accepts: (ip) => ip == baseline,
          reason: 'Explicit launcher executable did not bypass the VPN',
        );
        await _waitForIP(
          tester,
          launcher,
          child: child,
          accepts: (ip) => ip != baseline,
          reason: 'Exempting the launcher also exempted its unlisted child',
        );

        unawaited(appRouter.push(const AppsSplitTunneling()));
        final aliasesBeforeChild = await _persistedAliasRules();
        final childRule = await _addExecutable(tester, picker, child);
        await _expectPersistedRule(childRule, present: true);
        expect(
          (await _persistedAliasRules()).difference(aliasesBeforeChild),
          hasLength(1),
          reason: 'Selecting an executable did not save its alias rule',
        );
        await _captureScreenshot(tester, 'windows-selected-executable');
        for (final launch in childLaunches.entries) {
          await _waitForIP(
            tester,
            launcher,
            child: launch.value,
            accepts: (ip) => ip == baseline,
            reason: 'Selected child launched by ${launch.key} did not bypass',
          );
        }
        await _waitForIP(
          tester,
          unrelated,
          accepts: (ip) => ip != baseline,
          reason: 'A same-named executable in another folder bypassed the VPN',
        );

        // A removed executable must remain visible and removable in the app.
        final missingChild = await File(child).rename('$child.uninstalled');
        addTearDown(() async {
          if (await missingChild.exists()) await missingChild.rename(child);
        });
        container.invalidate(splitTunnelingAppsProvider);
        await container.read(splitTunnelingAppsProvider.future);
        await tester.pump(const Duration(milliseconds: 300));
        await revealBypassedApp(tester, _appRow(childRule));
        await _tap(
          tester,
          find.byKey(
            ValueKey(
              'toggle-split-tunnel-app:processPath:${windowsAppPathId(childRule)}',
            ),
          ),
        );
        await WidgetWaitUtils.waitForFinderToDisappear(
          tester,
          _appRow(childRule),
          timeout: const Duration(seconds: 20),
          reason: 'Manual executable was not removable',
        );
        await _expectPersistedRule(childRule, present: false);
        expect(
          await _persistedAliasRules(),
          aliasesBeforeChild,
          reason: 'Removing a missing executable left a hidden alias bypass',
        );
        await missingChild.rename(child);
        await _waitForIP(
          tester,
          launcher,
          child: _windowsPathName(child, 'GetShortPathNameW'),
          accepts: (ip) => ip != baseline,
          reason: 'Removing the child rule did not restore tunneled traffic',
        );

        appRouter.popUntilRoot();
        await tester.pump(const Duration(milliseconds: 400));
        await _tap(
          tester,
          find.byKey(const Key('home.split_tunneling_setting')),
        );
        await _tap(
          tester,
          find.byKey(const Key('split_tunneling.mode.include')),
        );
        await _tap(
          tester,
          find.byKey(const Key('split_tunneling.mode.confirm')),
        );
        await WidgetWaitUtils.waitForFinderToDisappear(
          tester,
          find.byKey(const Key('split_tunneling.mode.confirm')),
          timeout: const Duration(seconds: 30),
        );
        expect(
          await container.read(splitTunnelProvider.notifier).refresh(),
          isNull,
        );
        final included = await container.read(splitTunnelProvider.future);
        expect(included.policy, SplitTunnelPolicy.includeOnly);
        expect(included.appCount, 0);
        expect(included.websiteCount, 0);
        await _waitForIP(
          tester,
          launcher,
          child: child,
          accepts: (ip) => ip == baseline,
          reason: 'Empty Include only did not leave the child direct',
        );
        await _tap(tester, find.byKey(const Key('split_tunneling.apps_tile')));
        await _addExecutable(tester, picker, child, bypass: false);
        await _waitForIP(
          tester,
          launcher,
          child: child,
          accepts: (ip) => ip != baseline,
          reason: 'Include only did not tunnel the selected child',
        );
        for (final executable in [launcher, unrelated]) {
          await _waitForIP(
            tester,
            executable,
            accepts: (ip) => ip == baseline,
            reason: 'Include only tunneled an unselected executable',
          );
        }

        final search = find.byType(AppSearchBar);
        await _tap(
          tester,
          find.descendant(of: search, matching: find.byType(IconButton)).last,
        );
        await tester.enterText(
          find.descendant(of: search, matching: find.byType(TextField)),
          'no matching applications',
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(_appRow(childRule), findsNothing);
        await _tap(tester, find.byKey(const Key('split_tunneling.apps.clear')));
        final clearDeadline = DateTime.now().add(const Duration(seconds: 30));
        while (true) {
          await tester.pump(const Duration(milliseconds: 200));
          final cleared = _require(
            await service.getSplitTunnelState(),
            'Read cleared selectors',
          );
          if (cleared.appCount == 0) {
            for (final type in SplitTunnelState.appTypes) {
              expect(
                cleared.selectors(type),
                isEmpty,
                reason: 'Clear left hidden selectors',
              );
            }
            break;
          }
          if (DateTime.now().isAfter(clearDeadline)) {
            fail('Clear during search did not reach the daemon');
          }
        }
        await _waitForIP(
          tester,
          launcher,
          child: child,
          accepts: (ip) => ip == baseline,
          reason:
              'Clearing Include only selections did not restore direct traffic',
        );
      } finally {
        _require(
          await service.stopVPN().timeout(const Duration(seconds: 45)),
          'Disconnect after app split tunneling smoke',
        );
        appRouter.popUntilRoot();
        await tester.pump(const Duration(milliseconds: 400));
        await states.waitFor(
          tester,
          expected: [VPNStatus.disconnected],
          timeout: const Duration(seconds: 45),
          reason: 'VPN did not disconnect',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
