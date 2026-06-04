import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/available_servers.dart';

void main() {
  group('AvailableServers', () {
    test('fastestLanternServer only considers successful Lantern probes', () {
      final slow = _server(tag: 'slow', delay: 320);
      final failed = _server(tag: 'failed', delay: 0);
      final noProbe = _server(tag: 'no-probe');
      final fast = _server(tag: 'fast', delay: 85);
      final private = _server(tag: 'private', isLantern: false, delay: 40);

      final servers = AvailableServers([slow, failed, noProbe, fast, private]);

      expect(servers.fastestLanternServer, fast);
    });

    test(
      'warns before manually selecting Lantern servers without a successful probe',
      () {
        expect(
          _server(tag: 'reachable', delay: 100).shouldWarnBeforeManualSelection,
          isFalse,
        );
        expect(
          _server(tag: 'failed', delay: 0).shouldWarnBeforeManualSelection,
          isTrue,
        );
        expect(
          _server(tag: 'no-probe').shouldWarnBeforeManualSelection,
          isTrue,
        );
        expect(
          _server(
            tag: 'private',
            isLantern: false,
          ).shouldWarnBeforeManualSelection,
          isFalse,
        );
      },
    );
  });
}

Server _server({required String tag, bool isLantern = true, int? delay}) {
  return Server(
    tag: tag,
    type: 'samizdat',
    isLantern: isLantern,
    location: GeoLocation(
      country: 'United States',
      countryCode: 'US',
      city: 'New York',
      latitude: 40.7128,
      longitude: -74.006,
    ),
    selectionHistory: delay == null
        ? null
        : SelectionHistory(
            lastSuccessDelayMs: delay,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
  );
}
