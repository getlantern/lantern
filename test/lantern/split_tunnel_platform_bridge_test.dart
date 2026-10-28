import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.getlantern.lantern/method');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = LanternPlatformService();

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('state, policy and app clear use complete snapshots', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'normalizeSplitTunnelWebsite') {
        return '.xn--bcher-kva.de';
      }
      return jsonEncode({
        'enabled': true,
        'policy': 'include',
        'supported': true,
        'filters': {
          'DomainSuffix': ['.example.com'],
          'ProcessPath': ['missing.exe'],
        },
      });
    });
    for (final operation in [
      service.getSplitTunnelState(),
      service.switchSplitTunnelPolicy('include'),
      service.clearSplitTunnelApps(),
    ]) {
      final result = await operation;
      result.fold((failure) => fail('$failure'), (state) {
        expect(state.enabled, isTrue);
        expect(state.supported, isTrue);
        expect(state.policy, SplitTunnelPolicy.includeOnly);
        expect(state.selectors(SplitTunnelFilterType.processPath), [
          'missing.exe',
        ]);
      });
    }
    final normalized = await service.normalizeSplitTunnelWebsite('*.bücher.de');
    expect(normalized.getOrElse((_) => ''), '.xn--bcher-kva.de');
    expect(calls.map((call) => call.method), [
      'getSplitTunnelState',
      'switchSplitTunnelPolicy',
      'clearSplitTunnelApps',
      'normalizeSplitTunnelWebsite',
    ]);
    expect(calls[1].arguments, {'policy': 'include'});
    expect(calls[3].arguments, {'input': '*.bücher.de'});
  });

  test(
    'read and mutation failures are not successful empty responses',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'SPLIT_TUNNEL_ERROR',
          message: 'saved but apply failed',
        );
      });
      expect((await service.getSplitTunnelState()).isLeft(), isTrue);
      expect(
        (await service.switchSplitTunnelPolicy('include')).isLeft(),
        isTrue,
      );
      expect((await service.clearSplitTunnelApps()).isLeft(), isTrue);
      expect(
        (await service.normalizeSplitTunnelWebsite('*ir')).isLeft(),
        isTrue,
      );
      expect(
        (await service.getSplitTunnelItems(
          SplitTunnelFilterType.domainSuffix,
        )).isLeft(),
        isTrue,
      );
    },
  );

  test(
    'legacy daemon reports its actual policy without claiming support',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => jsonEncode({
          'enabled': true,
          'policy': 'include',
          'supported': false,
          'filters': {},
        }),
      );
      final result = await service.getSplitTunnelState();
      result.fold((failure) => fail('$failure'), (state) {
        expect(state.supported, isFalse);
        expect(state.policy, SplitTunnelPolicy.includeOnly);
      });
    },
  );

  test(
    'invalid state and filter payloads propagate as read failures',
    () async {
      for (final payload in [null, '', '{}', '[]']) {
        messenger.setMockMethodCallHandler(channel, (_) async => payload);
        expect((await service.getSplitTunnelState()).isLeft(), isTrue);
      }
      messenger.setMockMethodCallHandler(channel, (_) async => '{}');
      expect(
        (await service.getSplitTunnelItems(
          SplitTunnelFilterType.domainSuffix,
        )).isLeft(),
        isTrue,
      );
      messenger.setMockMethodCallHandler(channel, (_) async => '[]');
      expect(
        (await service.getSplitTunnelItems(
          SplitTunnelFilterType.domainSuffix,
        )).getOrElse((_) => ['error']),
        isEmpty,
      );
    },
  );
}
