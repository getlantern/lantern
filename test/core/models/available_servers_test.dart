import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/available_servers.dart';

void main() {
  group('AvailableServers', () {
    test(
      'fastestLanternServer only considers usable successful Lantern probes',
      () {
        final slow = _server(tag: 'slow', delay: 320);
        final failed = _server(tag: 'failed', delay: 0, failures: 3);
        final noProbe = _server(tag: 'no-probe');
        final staleFast = _server(tag: 'stale-fast', delay: 10, failures: 3);
        final fast = _server(tag: 'fast', delay: 85);
        final private = _server(tag: 'private', isLantern: false, delay: 40);

        final servers = AvailableServers([
          slow,
          failed,
          noProbe,
          staleFast,
          fast,
          private,
        ]);

        expect(servers.fastestLanternServer, fast);
      },
    );

    test('lanternServerLocations picks one best server per location', () {
      final nyFailed = _server(
        tag: 'ny-failed',
        delay: 0,
        failures: 2,
        city: 'New York',
      );
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
      // A location whose only server has never been probed is unknown, not
      // unreachable — it must not surface the warning during convergence.
      final la = locations.singleWhere((s) => s.location.city == 'Los Angeles');
      expect(la.isAwaitingProbe, isTrue);
      expect(la.shouldWarnBeforeManualSelection, isFalse);
    });

    test(
      'lanternServerLocations prefers an untested representative over a failed one',
      () {
        final failed = _server(
          tag: 'a-failed',
          delay: 0,
          failures: 4,
          city: 'Berlin',
          country: 'Germany',
          countryCode: 'DE',
        );
        final untested = _server(
          tag: 'z-untested',
          city: 'Berlin',
          country: 'Germany',
          countryCode: 'DE',
        );

        final locations = AvailableServers([
          failed,
          untested,
        ]).lanternServerLocations;

        expect(locations, hasLength(1));
        // Even though 'a-failed' sorts first by tag, the untested server
        // represents the location so it is unknown, not unavailable.
        expect(locations.single.isAwaitingProbe, isTrue);
        expect(locations.single.shouldWarnBeforeManualSelection, isFalse);
      },
    );

    test(
      'lanternServerLocations marks a fully-failed location unreachable',
      () {
        final failedA = _server(
          tag: 'mad-a',
          delay: 0,
          failures: 5,
          city: 'Madrid',
          country: 'Spain',
          countryCode: 'ES',
        );
        final failedB = _server(
          tag: 'mad-b',
          delay: 0,
          failures: 3,
          city: 'Madrid',
          country: 'Spain',
          countryCode: 'ES',
        );

        final locations = AvailableServers([
          failedA,
          failedB,
        ]).lanternServerLocations;

        expect(locations, hasLength(1));
        expect(locations.single.isProbedUnreachable, isTrue);
        expect(locations.single.shouldWarnBeforeManualSelection, isTrue);
      },
    );

    test(
      'lanternServerLocations keeps a location available while one server is '
      'only flapping below threshold',
      () {
        final hardFailed = _server(
          tag: 'rome-a',
          delay: 0,
          failures: 6,
          city: 'Rome',
          country: 'Italy',
          countryCode: 'IT',
        );
        final flapping = _server(
          tag: 'rome-b',
          delay: 0,
          failures: 2,
          city: 'Rome',
          country: 'Italy',
          countryCode: 'IT',
        );

        final locations = AvailableServers([
          hardFailed,
          flapping,
        ]).lanternServerLocations;

        expect(locations, hasLength(1));
        // The below-threshold server represents the location, so it isn't
        // declared unavailable while a server might still recover.
        expect(locations.single.isProbedUnreachable, isFalse);
        expect(locations.single.shouldWarnBeforeManualSelection, isFalse);
      },
    );

    test(
      'lanternServerLocations does not prefer stale latency from a hard-failed server',
      () {
        final staleFailed = _server(
          tag: 'paris-fast-stale',
          delay: 10,
          failures: 3,
          city: 'Paris',
          country: 'France',
          countryCode: 'FR',
        );
        final usable = _server(
          tag: 'paris-usable',
          delay: 100,
          city: 'Paris',
          country: 'France',
          countryCode: 'FR',
        );

        final locations = AvailableServers([
          staleFailed,
          usable,
        ]).lanternServerLocations;

        expect(locations, hasLength(1));
        expect(locations.single, usable);
        expect(locations.single.shouldWarnBeforeManualSelection, isFalse);
      },
    );
  });

  group('Server probe state', () {
    test('reachable: successful probe', () {
      final s = _server(tag: 'reachable', delay: 100);
      expect(s.hasSuccessfulProbe, isTrue);
      expect(s.hasProbeVerdict, isTrue);
      expect(s.isAwaitingProbe, isFalse);
      expect(s.isProbedUnreachable, isFalse);
      expect(s.shouldWarnBeforeManualSelection, isFalse);
    });

    test('probed-and-failed past threshold: warns and is unreachable', () {
      final s = _server(tag: 'failed', delay: 0, failures: 3);
      expect(s.hasSuccessfulProbe, isFalse);
      expect(s.hasProbeVerdict, isTrue);
      expect(s.hasFailedProbeEvidence, isTrue);
      expect(s.isAwaitingProbe, isFalse);
      expect(s.isProbedUnreachable, isTrue);
      expect(s.shouldWarnBeforeManualSelection, isTrue);
    });

    test(
      'stale successful probe with current sustained failures: warns and is unreachable',
      () {
        final s = _server(tag: 'stale-failed', delay: 100, failures: 3);
        expect(s.hasSuccessfulProbe, isTrue);
        expect(s.hasProbeVerdict, isTrue);
        expect(s.hasFailedProbeEvidence, isTrue);
        expect(s.isAwaitingProbe, isFalse);
        expect(s.isProbedUnreachable, isTrue);
        expect(s.shouldWarnBeforeManualSelection, isTrue);
      },
    );

    test('transient failure below threshold: uncertain, not unreachable', () {
      final s = _server(tag: 'flapping', delay: 0, failures: 2);
      expect(s.hasSuccessfulProbe, isFalse);
      expect(s.hasProbeVerdict, isTrue);
      expect(s.hasFailedProbeEvidence, isFalse);
      // Has a verdict, so not unknown; below threshold, so not "unreachable":
      // shown as a normal row, no spinner and no warning.
      expect(s.isAwaitingProbe, isFalse);
      expect(s.isProbedUnreachable, isFalse);
      expect(s.shouldWarnBeforeManualSelection, isFalse);
    });

    test('untested (no history): unknown, never unreachable', () {
      final s = _server(tag: 'no-probe');
      expect(s.hasSuccessfulProbe, isFalse);
      expect(s.hasProbeVerdict, isFalse);
      expect(s.isAwaitingProbe, isTrue);
      expect(s.isProbedUnreachable, isFalse);
      expect(s.shouldWarnBeforeManualSelection, isFalse);
    });

    test('history present but no probe verdict: still unknown', () {
      // e.g. a user-traffic-only history with no probe outcome yet.
      final s = _server(tag: 'no-verdict', delay: 0, failures: 0);
      expect(s.hasProbeVerdict, isFalse);
      expect(s.isAwaitingProbe, isTrue);
      expect(s.shouldWarnBeforeManualSelection, isFalse);
    });

    test('private servers never warn or await probes', () {
      final s = _server(tag: 'private', isLantern: false);
      expect(s.isAwaitingProbe, isFalse);
      expect(s.isProbedUnreachable, isFalse);
      expect(s.shouldWarnBeforeManualSelection, isFalse);
    });
  });

  group('user_failures deserialization', () {
    // lantern-box v0.0.104 changed each entry from a bare RFC3339 timestamp to
    // a {"at": ..., "kind": ...} object. Both have to parse: the object form is
    // what current lantern-box sends, the string form is what a client paired
    // with a pre-v0.0.104 one would see.
    test('parses the object form', () {
      final history = SelectionHistory.fromJson({
        'last_success_delay_ms': 2556,
        'consecutive_failures': 2,
        'user_failures': [
          {'at': '2026-07-23T19:23:18.956396324+08:00', 'kind': 'unknown'},
          {'at': '2026-07-23T19:24:11.696763492+08:00', 'kind': 'stall'},
        ],
        'updated_at': '2026-07-23T19:26:52.297493639+08:00',
      });

      expect(history.userFailures, [
        DateTime.parse('2026-07-23T19:23:18.956396324+08:00'),
        DateTime.parse('2026-07-23T19:24:11.696763492+08:00'),
      ]);
    });

    test('parses an object form with no kind', () {
      final history = SelectionHistory.fromJson({
        'user_failures': [
          {'at': '2026-07-06T12:00:00Z'},
        ],
      });

      expect(history.userFailures, [DateTime.parse('2026-07-06T12:00:00Z')]);
    });

    test('parses the legacy bare-timestamp form', () {
      final history = SelectionHistory.fromJson({
        'user_failures': ['2026-07-06T12:00:00Z', '2026-07-06T12:01:00Z'],
      });

      expect(history.userFailures, [
        DateTime.parse('2026-07-06T12:00:00Z'),
        DateTime.parse('2026-07-06T12:01:00Z'),
      ]);
    });

    test('parses a window holding both forms at once', () {
      final history = SelectionHistory.fromJson({
        'user_failures': [
          '2026-07-06T12:00:00Z',
          {'at': '2026-07-06T12:01:00Z', 'kind': 'reset'},
        ],
      });

      expect(history.userFailures, [
        DateTime.parse('2026-07-06T12:00:00Z'),
        DateTime.parse('2026-07-06T12:01:00Z'),
      ]);
    });

    test('an absent window parses as empty', () {
      expect(SelectionHistory.fromJson({}).userFailures, isEmpty);
    });

    // A window this side can't read must cost us the entries, not the server.
    test('drops entries with no readable timestamp', () {
      final history = SelectionHistory.fromJson({
        'user_failures': [
          {'kind': 'stall'},
          {'at': null},
          {'at': 1752580800},
          'the beginning of time',
          42,
          null,
          {'at': '2026-07-06T12:00:00Z', 'kind': 'stall'},
        ],
      });

      expect(history.userFailures, [DateTime.parse('2026-07-06T12:00:00Z')]);
    });

    // Freshdesk #180591: a single server carrying the object form threw during
    // Server.fromJson, and because AvailableServers.fromJson maps over the
    // whole list, that one entry took down all 55 servers — leaving the client
    // with no server list at all.
    test('parses a list where only one server carries user_failures', () {
      final servers = AvailableServers.fromJson(
        _payload([
          _serverJson(tag: 'no-failures'),
          _serverJson(
            tag: 'has-failures',
            userFailures: [
              {'at': '2026-07-23T19:23:18.956396324+08:00', 'kind': 'unknown'},
            ],
          ),
        ]),
      );

      expect(servers.servers.map((s) => s.tag), [
        'no-failures',
        'has-failures',
      ]);
      expect(
        servers.serverByTag('has-failures')!.selectionHistory!.userFailures,
        hasLength(1),
      );
    });
  });
}

/// Round-trips through JSON so element types match what the platform channel
/// hands us — `List<dynamic>` of `Map<String, dynamic>`, nested maps likewise —
/// rather than the sharper literal types the analyzer infers here.
List<dynamic> _payload(List<Map<String, dynamic>> servers) =>
    jsonDecode(jsonEncode(servers)) as List<dynamic>;

/// One server as it looks after `jsonDecode` of the payload radiance sends.
Map<String, dynamic> _serverJson({
  required String tag,
  List<Map<String, dynamic>>? userFailures,
}) => {
  'tag': tag,
  'type': 'samizdat',
  'isLantern': true,
  'outbound': {'type': 'samizdat', 'tag': tag, 'server': '203.0.113.7'},
  'location': {
    'country': 'U.S.A.',
    'city': 'Chicago',
    'country_code': 'US',
    'latitude': 41.8781,
    'longitude': -87.6298,
  },
  'selection_history': {
    'last_success_delay_ms': 1264,
    'last_outcome_at': '2026-07-23T19:26:51.648896087+08:00',
    'user_failures': ?userFailures,
    'updated_at': '2026-07-23T19:26:51.648896087+08:00',
  },
};

Server _server({
  required String tag,
  bool isLantern = true,
  int? delay,
  int failures = 0,
  String country = 'United States',
  String countryCode = 'US',
  String city = 'New York',
}) {
  final hasHistory = delay != null || failures > 0;
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
    selectionHistory: !hasHistory
        ? null
        : SelectionHistory(
            lastSuccessDelayMs: delay ?? 0,
            consecutiveFailures: failures,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
  );
}
