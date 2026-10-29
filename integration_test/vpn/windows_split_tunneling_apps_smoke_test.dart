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
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';
import 'package:lantern/features/split_tunneling/windows_executable_picker.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/main.dart' as app;
import 'package:path/path.dart' as p;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';
import 'split_tunneling_smoke_helpers.dart';
import 'vpn_smoke_helpers.dart';
import 'windows_firefox_smoke.dart';
import 'windows_routing_evidence.dart';

// The native dialog is tested once; path edge cases use this deterministic picker.
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
    result.fold((_) => fail('$operation failed'), (value) => value);

Finder _appRow(String path) =>
    find.byKey(ValueKey('split-tunnel-app:${windowsAppPathId(path)}'));

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
  String path,
) async {
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
  return _finishAddingExecutable(tester, before);
}

Future<Set<String>> _selectedPaths() async => _require(
  await sl<LanternService>().getSplitTunnelItems(
    SplitTunnelFilterType.processPath,
  ),
  'Read executable rules',
).toSet();

Future<String> _finishAddingExecutable(
  WidgetTester tester,
  Set<String> before,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    final confirmation = find.byType(AlertDialog);
    final add = find.descendant(
      of: confirmation,
      matching: find.widgetWithText(PrimaryButton, 'add'.i18n),
    );
    final addBrowser = find.descendant(
      of: confirmation,
      matching: find.widgetWithText(SecondaryButton, 'add_anyway'.i18n),
    );
    if (add.evaluate().isNotEmpty || addBrowser.evaluate().isNotEmpty) {
      await _tap(tester, addBrowser.evaluate().isNotEmpty ? addBrowser : add);
      continue;
    }
    final added = (await _selectedPaths()).difference(before);
    if (added.isNotEmpty) {
      expect(added, hasLength(1));
      final canonicalPath = added.single;
      await closeInstalledAppSearch(tester);
      await revealBypassedApp(tester, _appRow(canonicalPath));
      return canonicalPath;
    }
  }
  fail('Selected executable was not saved');
}

Future<String> _selectInstalledExecutable(
  WidgetTester tester,
  ProviderContainer container,
  String executable,
) async {
  await WidgetWaitUtils.waitForFinder(
    tester,
    find.byType(WindowsExecutablePicker),
    timeout: const Duration(seconds: 20),
  );
  final path = _canonicalPath(executable);
  final discovered = await container
      .read(appsDataProvider.future)
      .timeout(const Duration(seconds: 60));
  final matches = discovered.where(
    (app) => windowsAppPathId(app.appPath) == path,
  );
  expect(matches, isNotEmpty, reason: 'Executable was not discovered: $path');
  final before = await _selectedPaths();
  expect(before.map(windowsAppPathId), isNot(contains(path)));
  await expectInstalledApp(
    tester,
    query: matches.first.name,
    row: _appRow(path),
    select: true,
  );
  final selected = await _finishAddingExecutable(tester, before);
  expect(windowsAppPathId(selected), path);
  await _expectPersistedRule(selected, present: true);
  return selected;
}

Future<void> _removeExecutable(WidgetTester tester, String path) async {
  await revealBypassedApp(tester, _appRow(path));
  await _tap(
    tester,
    find.byKey(ValueKey('toggle-split-tunnel-app:${windowsAppPathId(path)}')),
  );
  await _expectPersistedRule(path, present: false);
}

String _canonicalPath(String path) =>
    windowsAppPathId(_windowsPathName(path, 'GetLongPathNameW'));

Future<String> _addWithNativeDialog(WidgetTester tester, String path) async {
  const script = String.fromEnvironment('SPLIT_TUNNEL_FILE_DIALOG_SCRIPT');
  expect(script, isNotEmpty);
  final before = await _selectedPaths();
  final button = find.byWidgetPredicate(
    (widget) =>
        widget is SecondaryButton &&
        widget.key == const ValueKey('add-windows-executable') &&
        widget.enabled,
  );
  await WidgetWaitUtils.waitForFinder(
    tester,
    button,
    timeout: const Duration(seconds: 20),
    reason: 'Add executable did not become enabled',
  );
  final automation = await Process.start('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    script,
    '-AppProcessId',
    '$pid',
    '-FilePath',
    path,
  ], runInShell: false);
  final completed = Future.wait<Object>([
    automation.exitCode,
    automation.stdout.transform(utf8.decoder).join(),
    automation.stderr.transform(utf8.decoder).join(),
  ]);
  try {
    await _tap(tester, button);
    final result = await completed.timeout(const Duration(seconds: 35));
    expect(
      result[0],
      0,
      reason: 'Native file dialog failed: ${result[1]} ${result[2]}',
    );
    return await _finishAddingExecutable(tester, before);
  } finally {
    automation.kill();
    await automation.exitCode.timeout(const Duration(seconds: 5));
  }
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
      row: _appRow(path),
    );
    debugPrint('Discovered ${entry.key} in Installed Apps: $path');
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
    try {
      final connection = await probeWindowsConnection(executable, child: child);
      final ip = connection['publicIP'] as String;
      if (accepts(ip)) return ip;
    } on StateError catch (error) {
      debugPrint('IP probe failed: $error');
    } on TimeoutException catch (error) {
      debugPrint('IP probe timed out: $error');
    }
    await tester.pump(const Duration(seconds: 2));
  }
  fail(reason);
}

Future<void> _expectOwnedRoute(
  WindowsRoutingEvidence evidence,
  String executable, {
  String? child,
  bool udp = false,
  required bool bypass,
  required String baseline,
  required String scenario,
}) async {
  await _expectLiveRoute(
    evidence,
    executable: child ?? executable,
    bypass: bypass,
    baseline: baseline,
    scenario: '$scenario (${udp ? 'UDP' : 'TCP'})',
    probe: () async {
      final result = await probeWindowsConnection(
        executable,
        child: child,
        udp: udp,
      );
      return (address: result['publicIP'] as String, connections: [result]);
    },
  );
}

Future<void> _expectLiveRoute(
  WindowsRoutingEvidence evidence, {
  required String executable,
  required bool bypass,
  required String baseline,
  required String scenario,
  required Future<({String address, List<Map<String, dynamic>> connections})>
  Function()
  probe,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  Object? lastFailure;
  // Rule-file reloads are asynchronous. Every attempt uses a new connection
  // and a new log boundary so an earlier route cannot satisfy the assertion.
  while (DateTime.now().isBefore(deadline)) {
    final since = evidence.mark;
    try {
      final result = await probe();
      if ((result.address == baseline) != bypass) {
        lastFailure =
            'Observed ${result.address}; direct baseline is $baseline';
      } else {
        await evidence.expectRoute(
          since: since,
          connections: result.connections,
          executable: executable,
          normalizePath: _canonicalPath,
          bypass: bypass,
          scenario: scenario,
          publicIP: result.address,
        );
        debugPrint('Verified $scenario: owner, socket, rule and outbound');
        return;
      }
    } on StateError catch (error) {
      lastFailure = error;
    } on TimeoutException catch (error) {
      lastFailure = error;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$scenario did not follow the selection: $lastFailure');
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
  await runWindowsSmokeCommand(cli, [
    'split-tunnel',
    operation,
    '--type',
    'process-path',
    '--value',
    path,
  ]);
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
    'Windows installed apps and launcher children follow executable rules',
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
      const firefox = String.fromEnvironment('SPLIT_TUNNEL_FIREFOX_EXE');
      const geckodriver = String.fromEnvironment(
        'SPLIT_TUNNEL_GECKODRIVER_EXE',
      );
      expect(await File(firefox).exists(), isTrue);
      expect(await File(geckodriver).exists(), isTrue);
      const artifactDirectory = String.fromEnvironment(
        'SPLIT_TUNNEL_SCREENSHOT_DIR',
        defaultValue: 'build/windows-split-tunnel-smoke',
      );

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
      final nativePicker = await copyProbe(
        'Native File Picker',
        'Native Picker Probe.exe',
      );
      final registeredLauncher = registeredExecutables['Start Menu launcher']!;
      final registeredGame = registeredExecutables['App Paths game']!;
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
      final wasEnabled = _require(
        await service.isSplitTunnelingEnabled(),
        'Read split tunneling',
      );
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
        _require(
          await service.setSplitTunnelingEnabled(wasEnabled),
          'Restore split tunneling',
        );
      });
      for (final path in [
        launcher,
        childLong,
        legacyRule,
        nativePicker,
        registeredLauncher,
        registeredGame,
        firefox,
      ]) {
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
          await service.setSplitTunnelingEnabled(true),
          'Enable split tunneling',
        );

        final evidence = await WindowsRoutingEvidence.start(
          cliPath,
          artifactDirectory,
        );
        addTearDown(evidence.close);
        final picker = _ExecutablePicker();
        final originalPicker = FileSelectorPlatform.instance;
        addTearDown(() => FileSelectorPlatform.instance = originalPicker);
        final baseline = await _waitForIP(
          tester,
          launcher,
          child: child,
          accepts: (_) => true,
          reason: 'Could not get the direct baseline IP',
        );
        final udpConnection = await probeWindowsConnection(
          registeredGame,
          udp: true,
        );
        final udpBaseline = udpConnection['publicIP'] as String;
        Future<void> expectRegisteredChild({
          required bool bypass,
          required String scenario,
        }) async {
          for (final udp in [false, true]) {
            await _expectOwnedRoute(
              evidence,
              registeredLauncher,
              child: registeredGame,
              udp: udp,
              bypass: bypass,
              baseline: udp ? udpBaseline : baseline,
              scenario: scenario,
            );
          }
        }

        unawaited(appRouter.push(const AppsSplitTunneling()));
        await WidgetWaitUtils.waitForFinder(
          tester,
          find.byType(WindowsExecutablePicker),
          timeout: const Duration(seconds: 20),
        );
        await container.read(splitTunnelingAppsProvider.future);
        await _expectRegisteredApps(tester, container, {
          ...registeredExecutables,
          'Installed Firefox': firefox,
        });
        await tester.ensureVisible(find.byType(WindowsExecutablePicker));
        await _captureScreenshot(tester, 'windows-executable-picker');
        final nativeRule = await _addWithNativeDialog(tester, nativePicker);
        expect(windowsAppPathId(nativeRule), _canonicalPath(nativePicker));
        await _expectPersistedRule(nativeRule, present: true);
        await _removeExecutable(tester, nativeRule);

        FileSelectorPlatform.instance = picker;
        await _selectInstalledExecutable(tester, container, registeredLauncher);
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

        await _expectOwnedRoute(
          evidence,
          registeredLauncher,
          bypass: true,
          baseline: baseline,
          scenario: 'Discovered launcher bypasses',
        );
        await expectRegisteredChild(
          bypass: false,
          scenario: 'Unselected registered child stays tunneled',
        );
        unawaited(appRouter.push(const AppsSplitTunneling()));
        final registeredGameRule = await _selectInstalledExecutable(
          tester,
          container,
          registeredGame,
        );
        await _captureScreenshot(tester, 'windows-installed-game-selected');
        await expectRegisteredChild(
          bypass: true,
          scenario: 'Installed Apps selection bypasses registered child',
        );
        await _removeExecutable(tester, registeredGameRule);
        await expectRegisteredChild(
          bypass: false,
          scenario: 'Removing registered child restores VPN',
        );

        final firefoxRule = await _selectInstalledExecutable(
          tester,
          container,
          firefox,
        );
        await _captureScreenshot(tester, 'windows-firefox-selected');
        for (final bypass in [true, false]) {
          if (!bypass) await _removeExecutable(tester, firefoxRule);
          await _expectLiveRoute(
            evidence,
            executable: firefox,
            bypass: bypass,
            baseline: baseline,
            scenario: bypass
                ? 'Selected Firefox bypasses'
                : 'Removed Firefox returns to VPN',
            probe: () async {
              final browser = await probeFirefox(
                firefoxPath: firefox,
                geckodriverPath: geckodriver,
                artifactDirectory: artifactDirectory,
              );
              return (
                address: browser.address,
                connections: browser.connections,
              );
            },
          );
        }

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
            ValueKey('toggle-split-tunnel-app:${windowsAppPathId(childRule)}'),
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
