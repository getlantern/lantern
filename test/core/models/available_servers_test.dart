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

    test('lanternServerLocations picks one best server per location', () {
      final nyFailed = _server(tag: 'ny-failed', delay: 0, city: 'New York');
      final nySlow = _server(tag: 'ny-slow', delay: 220, city: 'New York');
      final nyFast = _server(tag: 'ny-fast', delay: 90, city: 'New York');
      final laNoProbe = _server(tag: 'la-no-probe', city: 'Los Angeles');
      final private = _server(
        tag: 'private',
        isLantern: false,
        delay: 20,
        city: 'New York',
      );

      final locations = AvailableServers([
        nyFailed,
        nySlow,
        nyFast,
        laNoProbe,
        private,
      ]).lanternServerLocations;

      expect(locations, hasLength(2));
      expect(
        locations.singleWhere((s) => s.location.city == 'New York'),
        nyFast,
      );
      expect(
        locations
            .singleWhere((s) => s.location.city == 'Los Angeles')
            .shouldWarnBeforeManualSelection,
        isTrue,
      );
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

Server _server({
  required String tag,
  bool isLantern = true,
  int? delay,
  String country = 'United States',
  String countryCode = 'US',
  String city = 'New York',
}) {
  return Server(
    tag: tag,
    type: 'samizdat',
    isLantern: isLantern,
    location: GeoLocation(
      country: country,
      countryCode: countryCode,
      city: city,
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
