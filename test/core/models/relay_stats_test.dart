import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/int.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/relay_stats.dart';

void main() {
  group('RelayCounterTracker', () {
    RelayDelta apply(
      RelayCounterTracker t, {
      String epoch = 'run-1',
      int down = 0,
      int up = 0,
      Map<String, ByteCounts> peers = const {},
      Set<String> present = const {},
    }) => t.apply(
      epoch: epoch,
      down: down,
      up: up,
      peers: peers,
      present: present,
    );

    test('first snapshot is only a baseline', () {
      final t = RelayCounterTracker();
      final d = apply(
        t,
        down: 5000,
        up: 700,
        peers: {'192.0.2.1': (down: 5000, up: 700)},
        present: {'192.0.2.1'},
      );
      expect(d.down, 0);
      expect(d.up, 0);
      expect(d.peers, isEmpty);
      expect(d.arrivals, isEmpty);
    });

    test('same epoch yields per-total and per-IP deltas', () {
      final t = RelayCounterTracker();
      apply(t, down: 100, up: 10, peers: {'a': (down: 100, up: 10)});
      final d = apply(
        t,
        down: 350,
        up: 40,
        peers: {'a': (down: 300, up: 30), 'b': (down: 50, up: 0)},
      );
      expect(d.down, 250);
      expect(d.up, 30);
      expect(d.reset, isFalse);
      expect(d.peers['a'], (down: 200, up: 20));
      expect(d.peers['b'], (down: 50, up: 0));
    });

    test('unchanged peers produce no per-IP delta', () {
      final t = RelayCounterTracker();
      apply(t, down: 100, peers: {'a': (down: 100, up: 0)});
      final d = apply(t, down: 100, peers: {'a': (down: 100, up: 0)});
      expect(d.down, 0);
      expect(d.peers, isEmpty);
    });

    test('either counter going backwards resets both: delta is current', () {
      final t = RelayCounterTracker();
      apply(t, down: 1000, up: 500, peers: {'a': (down: 1000, up: 500)});
      final d = apply(t, down: 40, up: 600, peers: {'a': (down: 40, up: 600)});
      expect(d.down, 40);
      expect(d.up, 600);
      expect(d.reset, isTrue);
      expect(d.peers['a'], (down: 40, up: 600));
      final e = apply(t, down: 50, up: 10, peers: {'a': (down: 50, up: 10)});
      expect((e.down, e.up), (50, 10));
      expect(e.peers['a'], (down: 50, up: 10));
    });

    test('a restored watermark counts the same epoch from where it left', () {
      final t = RelayCounterTracker()
        ..restore(epoch: 'run-1', down: 100, up: 10);
      final d = apply(
        t,
        down: 1000,
        up: 40,
        peers: {'a': (down: 900, up: 30)},
        present: {'a'},
      );
      expect((d.down, d.up, d.reset), (900, 30, false));
      // Peer counters were not persisted, so they only set a baseline.
      expect(d.peers, isEmpty);
      expect(d.arrivals, isEmpty);
      expect(t.watermark, (epoch: 'run-1', down: 1000, up: 40));
      final next = apply(
        t,
        down: 1100,
        up: 40,
        peers: {'a': (down: 1000, up: 30)},
      );
      expect(next.down, 100);
      expect(next.peers['a'], (down: 100, up: 0));
    });

    test('a restored watermark from another epoch counts from zero', () {
      final t = RelayCounterTracker()
        ..restore(epoch: 'run-0', down: 100, up: 10);
      final d = apply(t, down: 70, up: 7, peers: {'a': (down: 70, up: 7)});
      expect((d.down, d.up, d.reset), (70, 7, true));
      expect(d.peers['a'], (down: 70, up: 7));
    });

    test('an empty restored epoch keeps the first snapshot a baseline', () {
      final t = RelayCounterTracker()..restore(epoch: '', down: 0, up: 0);
      expect(t.watermark, isNull);
      expect(apply(t, down: 500).down, 0);
    });

    test('a new epoch counts everything since it started', () {
      final t = RelayCounterTracker();
      apply(t, down: 9000, up: 900, peers: {'a': (down: 9000, up: 900)});
      final d = apply(
        t,
        epoch: 'run-2',
        down: 300,
        up: 30,
        peers: {'b': (down: 300, up: 30)},
        present: {'b'},
      );
      expect(d.down, 300);
      expect(d.up, 30);
      expect(d.reset, isTrue);
      expect(d.peers, {'b': (down: 300, up: 30)});
      // Like the arrivals counter, the first snapshot of a new epoch does
      // not count people as arrivals.
      expect(d.arrivals, isEmpty);
      final next = apply(
        t,
        epoch: 'run-2',
        down: 400,
        up: 30,
        peers: {'b': (down: 400, up: 30)},
      );
      expect(next.down, 100);
      expect(next.peers, {'b': (down: 100, up: 0)});
    });

    test('a recently disconnected IP keeps diffing while still listed', () {
      final t = RelayCounterTracker();
      apply(t, peers: {'a': (down: 100, up: 0)}, present: {'a'});
      // Gone from peers but still in peerBytes: not a new arrival, and the
      // final bytes it moved before leaving are attributed.
      final d = apply(t, peers: {'a': (down: 180, up: 5)}, present: {});
      expect(d.arrivals, isEmpty);
      expect(d.peers['a'], (down: 80, up: 5));
      // Expired from peerBytes, then back: counted from zero and as a new
      // arrival.
      apply(t);
      final back = apply(t, peers: {'a': (down: 30, up: 0)}, present: {'a'});
      expect(back.peers['a'], (down: 30, up: 0));
      expect(back.arrivals, {'a'});
    });

    test('a peer that came and went between snapshots still arrives', () {
      final t = RelayCounterTracker();
      apply(t);
      final d = apply(t, down: 64, peers: {'c': (down: 64, up: 0)});
      expect(d.arrivals, {'c'});
      expect(d.peers['c'], (down: 64, up: 0));
    });

    test('arrivals work without peerBytes (older radiance)', () {
      final t = RelayCounterTracker();
      apply(t, present: {'a'});
      final d = apply(t, present: {'a', 'b'});
      expect(d.arrivals, {'b'});
      expect(d.down, 0);
      expect(d.peers, isEmpty);
    });

    test('parsePeerBytes tolerates junk and sums repeated IPs', () {
      expect(RelayCounterTracker.parsePeerBytes(null), isEmpty);
      expect(RelayCounterTracker.parsePeerBytes('nope'), isEmpty);
      expect(
        RelayCounterTracker.parsePeerBytes([
          {'ip': '192.0.2.1', 'down': 10, 'up': 1},
          {'ip': '192.0.2.1', 'down': 5, 'up': 2},
          {'ip': '', 'down': 99, 'up': 99},
          {'down': 99},
          'garbage',
          {'ip': '192.0.2.2'},
        ]),
        {'192.0.2.1': (down: 15, up: 3), '192.0.2.2': (down: 0, up: 0)},
      );
    });
  });

  group('RelayStats', () {
    test('topCountries orders by bytes, then people, and limits', () {
      final stats = RelayStats(
        countries: {
          for (final (code, bytes, people) in [
            ('IR', 500, 1),
            ('RU', 900, 2),
            ('CN', 500, 4),
            ('', 100, 9),
            ('MM', 50, 1),
            ('BY', 10, 1),
          ])
            code: RelayCountryStats(code: code, down: bytes, people: people),
        },
      );
      expect(stats.topCountries().map((c) => c.code), [
        'RU',
        'CN',
        'IR',
        '',
        'MM',
      ]);
    });

    test('newSession keeps lifetime figures and clears the session', () {
      final stats = const RelayStats(
        available: true,
        sessionDown: 5,
        sessionUp: 6,
        lifetimeDown: 50,
        lifetimeUp: 60,
        speedDown: 7,
        speedUp: 8,
        countries: {'IR': RelayCountryStats(code: 'IR', down: 1)},
      ).newSession();
      expect(stats.sessionBytes, 0);
      expect(stats.speedDown, 0);
      expect(stats.lifetimeBytes, 110);
      expect(stats.countries.keys, ['IR']);
      expect(stats.available, isTrue);
    });
  });

  test('AppSetting round-trips relay totals and tolerates their absence', () {
    const setting = AppSetting(
      unboundedSessionCount: 7,
      unboundedBytesDown: 1234,
      unboundedBytesUp: 56,
      unboundedCountryStats: {
        'IR': RelayCountryStats(
          code: 'IR',
          name: 'Iran',
          down: 1000,
          up: 50,
          people: 3,
        ),
        '': RelayCountryStats(code: '', down: 234, up: 6, people: 1),
      },
    );
    final restored = AppSetting.fromJson(
      setting
          .copyWith(
            unboundedRelayEpoch: 'run-1',
            unboundedRelayMarkDown: 99,
            unboundedRelayMarkUp: 9,
          )
          .toJson(),
    );
    expect(
      (
        restored.unboundedRelayEpoch,
        restored.unboundedRelayMarkDown,
        restored.unboundedRelayMarkUp,
      ),
      ('run-1', 99, 9),
    );
    expect(restored.unboundedSessionCount, 7);
    expect(restored.unboundedBytesDown, 1234);
    expect(restored.unboundedBytesUp, 56);
    final iran = restored.unboundedCountryStats['IR']!;
    expect((iran.name, iran.down, iran.up, iran.people), ('Iran', 1000, 50, 3));
    expect(restored.unboundedCountryStats['']!.isUnknown, isTrue);

    final legacy = AppSetting.fromJson({'unboundedTotalHelped': 4});
    expect(legacy.unboundedSessionCount, 0);
    expect(legacy.unboundedBytesDown, 0);
    expect(legacy.unboundedCountryStats, isEmpty);
    expect(legacy.unboundedRelayEpoch, isEmpty);
  });

  test('siBytes uses SI units', () {
    expect(0.siBytes, '0 B');
    expect(999.siBytes, '999 B');
    expect(1000.siBytes, '1.0 kB');
    expect(1260.siBytes, '1.3 kB');
    expect(12345.siBytes, '12 kB');
    expect(999999.siBytes, '1.0 MB');
    expect(1200000000.siBytes, '1.2 GB');
    expect(3400000000000.siBytes, '3.4 TB');
  });
}
