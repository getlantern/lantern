import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/main.dart' as app;

import 'vpn_smoke_helpers.dart';

const _curlRule = r'^/usr/bin/curl$';
const _filter = SplitTunnelFilterType.processPathRegex;

T _value<T>(Either<Failure, T> result) =>
    result.fold((failure) => fail('$failure'), (value) => value);

Future<String> _curlPublicIp() async {
  final result = await Process.run('/usr/bin/curl', [
    '--disable',
    '--ipv4',
    '--noproxy',
    '*',
    '--connect-timeout',
    '5',
    '--max-time',
    '20',
    '--fail',
    '--silent',
    '--show-error',
    'https://api.ipify.org',
  ]).timeout(const Duration(seconds: 25));
  expect(result.exitCode, 0, reason: '${result.stderr}');
  final ip = '${result.stdout}'.trim();
  expect(InternetAddress.tryParse(ip)?.type, InternetAddressType.IPv4);
  return ip;
}

Future<String> _appPublicIp() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..findProxy = (_) => 'DIRECT';
  try {
    final request = await client.getUrl(Uri.parse('https://api.ipify.org'));
    final response = await request.close().timeout(const Duration(seconds: 20));
    expect(response.statusCode, HttpStatus.ok);
    final ip =
        (await response
                .transform(utf8.decoder)
                .join()
                .timeout(const Duration(seconds: 20)))
            .trim();
    expect(InternetAddress.tryParse(ip)?.type, InternetAddressType.IPv4);
    return ip;
  } finally {
    client.close(force: true);
  }
}

Future<void> _expectPublicIp(
  WidgetTester tester,
  LanternService service,
  String baseline, {
  required bool direct,
  Future<String> Function() fetchIp = _curlPublicIp,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  var matches = 0;
  while (DateTime.now().isBefore(deadline)) {
    expect(_value(await service.isVPNConnected()), isTrue);
    final matched = (await fetchIp() == baseline) == direct;
    expect(_value(await service.isVPNConnected()), isTrue);
    matches = matched ? matches + 1 : 0;
    if (matches == 2) return;
    await tester.pump(const Duration(seconds: 1));
  }
  fail('Traffic did not use the ${direct ? 'direct' : 'VPN'} route');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'macOS app exclusion changes actual traffic routing',
    (tester) async {
      await app.main();
      final finders = VpnSmokeFinders();
      final states = VpnStateFinders();
      await prepareVpnStartsDisconnectedForSmoke(
        tester,
        finders: finders,
        vpnStateFinders: states,
        scenario: 'macOS app split tunneling',
      );

      final service = sl<LanternService>();
      final smartRouting = _value(await service.isSmartRoutingEnabled());
      final splitEnabled = _value(await service.isSplitTunnelingEnabled());
      final hadRule = _value(
        await service.getSplitTunnelItems(_filter),
      ).contains(_curlRule);
      for (final filter in SplitTunnelFilterType.values) {
        final rules = _value(await service.getSplitTunnelItems(filter));
        expect(
          rules.where((rule) => filter != _filter || rule != _curlRule),
          isEmpty,
          reason: 'Use a smoke profile without other split-tunnel rules',
        );
      }

      // Restore settings before stopping the extension and handing IPC back to the app.
      addTearDown(() async => _value(await service.stopVPN()));
      addTearDown(
        () async => _value(await service.setRoutingMode(smartRouting)),
      );
      addTearDown(
        () async =>
            _value(await service.setSplitTunnelingEnabled(splitEnabled)),
      );
      addTearDown(
        () async => _value(
          await (hadRule
              ? service.addSplitTunnelItem(_filter, _curlRule)
              : service.removeSplitTunnelItem(_filter, _curlRule)),
        ),
      );

      _value(await service.setSplitTunnelingEnabled(false));
      _value(await service.setRoutingMode(false));
      final baseline = await _curlPublicIp();
      expect(await _appPublicIp(), baseline);
      _value(await service.startVPN());
      await states.waitFor(
        tester,
        expected: const [VPNStatus.connected],
        timeout: const Duration(seconds: 90),
        reason: 'VPN did not connect before testing app exclusions',
      );
      await _expectPublicIp(tester, service, baseline, direct: false);
      debugPrint('[E2E] curl uses the VPN before exclusion');

      _value(await service.addSplitTunnelItem(_filter, _curlRule));
      _value(await service.setSplitTunnelingEnabled(true));
      await _expectPublicIp(tester, service, baseline, direct: true);
      // Requests from the app must stay on the VPN while curl is excluded.
      await _expectPublicIp(
        tester,
        service,
        baseline,
        direct: false,
        fetchIp: _appPublicIp,
      );
      debugPrint(
        '[E2E] Excluded curl uses the direct route; control uses the VPN',
      );

      // Removing only the app rule must put the same request back through the VPN.
      _value(await service.removeSplitTunnelItem(_filter, _curlRule));
      await _expectPublicIp(tester, service, baseline, direct: false);
      debugPrint('[E2E] curl returns to the VPN after removing its exclusion');
    },
    skip: !Platform.isMacOS,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
