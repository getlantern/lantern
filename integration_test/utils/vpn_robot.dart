import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import 'app_robot.dart';

/// VPN feature robot (Android smoke path). Reads state by listening to
/// [vpnProvider] — the source of truth — while keeping taps UI-driven.
class VpnRobot {
  VpnRobot(this.tester, this.app);

  final WidgetTester tester;
  final AppRobot app;

  final Finder vpnToggle = find.byKey(const Key('vpn.toggle'));

  static const _stableStates = <VPNStatus>[
    VPNStatus.connected,
    VPNStatus.disconnected,
    VPNStatus.missingPermission,
    VPNStatus.error,
  ];

  ProviderContainer? _cachedContainer;
  ProviderSubscription<VPNStatus>? _errorSub;
  bool _sawError = false;

  /// Root [ProviderContainer], resolved once from a mounted home element and
  /// cached; it outlives route changes so later reads are route-independent.
  ProviderContainer get _container {
    final cached = _cachedContainer;
    if (cached != null) {
      return cached;
    }
    final elements = app.homeScreen.evaluate();
    if (elements.isEmpty) {
      fail('Cannot read VPN status: home screen is not mounted');
    }
    return _cachedContainer = ProviderScope.containerOf(
      elements.first,
      listen: false,
    );
  }

  VPNStatus get status => _container.read(vpnProvider);

  /// Compact state dump for failure messages: current status + the keyed
  /// widgets on screen (helps diagnose FTL failures where you can't attach a
  /// debugger).
  String debugSnapshot() =>
      'status=${status.name}, visibleKeys=${app.visibleKeys()}';

  /// Starts watching for the VPN entering [VPNStatus.error] at any point. Pair
  /// with [assertNoErrorsSeen] in a tearDown so an error blip anywhere in a
  /// scenario fails the test, not just at the checkpoints we happen to await.
  void beginErrorWatch() {
    _errorSub ??= _container.listen<VPNStatus>(vpnProvider, (_, next) {
      if (next == VPNStatus.error) {
        _sawError = true;
      }
    });
  }

  /// Closes the error watch and asserts no error was observed. Cheap and does
  /// not pump, so it is safe to call from a tearDown.
  void assertNoErrorsSeen() {
    _errorSub?.close();
    _errorSub = null;
    expect(
      _sawError,
      isFalse,
      reason: 'VPN entered error state during the scenario',
    );
  }

  /// Waits until [vpnProvider] reports one of [expected], or fails with
  /// [reason].
  Future<VPNStatus> waitForStatus(
    List<VPNStatus> expected, {
    required Duration timeout,
    required String reason,
  }) async {
    VPNStatus? matched;
    final subscription = _container.listen<VPNStatus>(vpnProvider, (_, next) {
      if (matched == null && expected.contains(next)) {
        matched = next;
      }
    }, fireImmediately: true);
    try {
      final end = DateTime.now().add(timeout);
      while (matched == null && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final result = matched;
      if (result != null) {
        return result;
      }
      fail('$reason (${debugSnapshot()})');
    } finally {
      subscription.close();
    }
  }

  Future<void> tapToggle() async {
    await tester.tap(vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Sets the routing mode via [radianceSettingsProvider] and waits for it to
  /// settle. Fails if the change is rejected or does not take effect.
  Future<void> setRoutingMode(RoutingMode mode) async {
    final result = await _container
        .read(radianceSettingsProvider.notifier)
        .setRoutingMode(mode);
    result.fold(
      (failure) => fail('Failed to set routing mode to ${mode.name}: $failure'),
      (_) {},
    );

    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (_container.read(radianceSettingsProvider).routingMode == mode) {
        return;
      }
    }
    fail('Routing mode did not settle to ${mode.name}');
  }

  /// Settles startup state and brings the VPN to a disconnected baseline,
  /// failing fast on error / missing-permission.
  Future<void> ensureDisconnected() async {
    var state = await waitForStatus(
      _stableStates,
      timeout: const Duration(seconds: 20),
      reason: 'VPN status did not settle to a stable state at startup',
    );

    if (state == VPNStatus.error) {
      fail('VPN reported error before connect smoke (${debugSnapshot()})');
    }
    if (state == VPNStatus.missingPermission) {
      fail(
        'VPN reported missing permission before connect smoke — the consent '
        'pre-grant likely failed (${debugSnapshot()})',
      );
    }

    if (state == VPNStatus.connected) {
      await tapToggle();
      state = await waitForStatus(
        const [VPNStatus.disconnected],
        timeout: const Duration(seconds: 45),
        reason: 'VPN did not reach disconnected state before connect smoke',
      );
    }

    if (state != VPNStatus.disconnected) {
      fail(
        'Expected disconnected state before connect smoke, got ${state.name}',
      );
    }
  }

  Future<void> connect() async {
    await tapToggle();
    await waitForStatus(
      const [VPNStatus.connected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not reach connected state within 45 seconds',
    );
  }

  Future<void> disconnectIfNeeded() async {
    final current = status;
    if (current != VPNStatus.connected && current != VPNStatus.connecting) {
      return;
    }
    await tapToggle();
    await waitForStatus(
      const [VPNStatus.disconnected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not return to disconnected state within 45 seconds',
    );
  }
}
