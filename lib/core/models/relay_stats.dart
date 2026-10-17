/// Lifetime bytes relayed to and from people in one country, plus how many
/// people from there arrived. [code] is the ISO country code, or
/// [unknownCode] for peers whose country could not be resolved.
class RelayCountryStats {
  static const unknownCode = '';

  final String code;
  final String name;
  final int down;
  final int up;
  final int people;

  const RelayCountryStats({
    required this.code,
    this.name = '',
    this.down = 0,
    this.up = 0,
    this.people = 0,
  });

  bool get isUnknown => code == unknownCode;
  int get bytes => down + up;

  RelayCountryStats add({
    String? name,
    int down = 0,
    int up = 0,
    int people = 0,
  }) => RelayCountryStats(
    code: code,
    name: (name == null || name.isEmpty) ? this.name : name,
    down: this.down + down,
    up: this.up + up,
    people: this.people + people,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'down': down,
    'up': up,
    'people': people,
  };

  factory RelayCountryStats.fromJson(String code, Map<String, dynamic> json) =>
      RelayCountryStats(
        code: code,
        name: (json['name'] ?? '').toString(),
        down: (json['down'] as num?)?.toInt() ?? 0,
        up: (json['up'] as num?)?.toInt() ?? 0,
        people: (json['people'] as num?)?.toInt() ?? 0,
      );

  static Map<String, RelayCountryStats> mapFromJson(Object? json) {
    if (json is! Map) return const {};
    return {
      for (final e in json.entries)
        if (e.value is Map)
          e.key.toString(): RelayCountryStats.fromJson(
            e.key.toString(),
            Map<String, dynamic>.from(e.value as Map),
          ),
    };
  }

  static Map<String, dynamic> mapToJson(Map<String, RelayCountryStats> map) => {
    for (final e in map.entries) e.key: e.value.toJson(),
  };
}

/// Unbounded data-relay figures shown under Advanced stats. Down is data sent
/// to the people helped, up is data received from them.
class RelayStats {
  /// Whether the backend reports byte counters at all; older radiance builds
  /// send snapshots without them.
  final bool available;
  final int sessionDown;
  final int sessionUp;
  final int lifetimeDown;
  final int lifetimeUp;

  /// Smoothed bytes per second.
  final double speedDown;
  final double speedUp;
  final Map<String, RelayCountryStats> countries;

  const RelayStats({
    this.available = false,
    this.sessionDown = 0,
    this.sessionUp = 0,
    this.lifetimeDown = 0,
    this.lifetimeUp = 0,
    this.speedDown = 0,
    this.speedUp = 0,
    this.countries = const {},
  });

  int get sessionBytes => sessionDown + sessionUp;
  int get lifetimeBytes => lifetimeDown + lifetimeUp;

  /// Countries ordered by data relayed, then by people helped.
  List<RelayCountryStats> topCountries([int limit = 5]) {
    final sorted = countries.values.toList()
      ..sort((a, b) {
        final byBytes = b.bytes.compareTo(a.bytes);
        return byBytes != 0 ? byBytes : b.people.compareTo(a.people);
      });
    return sorted.take(limit).toList();
  }

  /// Keeps lifetime totals and drops everything tied to the previous session.
  RelayStats newSession() => RelayStats(
    available: available,
    lifetimeDown: lifetimeDown,
    lifetimeUp: lifetimeUp,
    countries: countries,
  );

  RelayStats copyWith({
    bool? available,
    int? sessionDown,
    int? sessionUp,
    int? lifetimeDown,
    int? lifetimeUp,
    double? speedDown,
    double? speedUp,
    Map<String, RelayCountryStats>? countries,
  }) => RelayStats(
    available: available ?? this.available,
    sessionDown: sessionDown ?? this.sessionDown,
    sessionUp: sessionUp ?? this.sessionUp,
    lifetimeDown: lifetimeDown ?? this.lifetimeDown,
    lifetimeUp: lifetimeUp ?? this.lifetimeUp,
    speedDown: speedDown ?? this.speedDown,
    speedUp: speedUp ?? this.speedUp,
    countries: countries ?? this.countries,
  );
}

typedef ByteCounts = ({int down, int up});

/// What changed between two Unbounded snapshots.
class RelayDelta {
  final int down;
  final int up;
  final Map<String, ByteCounts> peers;

  /// Peer IPs that showed up since the previous snapshot.
  final Set<String> arrivals;

  /// True when the counters restarted, so [down]/[up] are not a rate over
  /// the snapshot interval.
  final bool reset;

  const RelayDelta({
    this.down = 0,
    this.up = 0,
    this.peers = const {},
    this.arrivals = const {},
    this.reset = false,
  });

  static const none = RelayDelta();
}

/// Turns the cumulative per-epoch byte counters of successive Unbounded
/// snapshots into deltas.
///
/// The first snapshot only sets the baseline: its counters may already have
/// been folded into persisted totals by an earlier app run. A new epoch means
/// the backend restarted, so its counters count from zero. A counter that
/// goes backwards within an epoch is treated the same way. Peers that drop
/// out of `peerBytes` are forgotten, so a returning peer counts from zero.
class RelayCounterTracker {
  String? _epoch;
  int _down = 0;
  int _up = 0;
  Map<String, ByteCounts> _peers = {};
  Set<String> _present = {};

  RelayDelta apply({
    required String epoch,
    required int down,
    required int up,
    required Map<String, ByteCounts> peers,
    required Set<String> present,
  }) {
    final allPresent = {...present, ...peers.keys};
    if (_epoch == null || _epoch != epoch) {
      final first = _epoch == null;
      _epoch = epoch;
      _down = down;
      _up = up;
      _peers = Map.of(peers);
      _present = allPresent;
      if (first) return RelayDelta.none;
      return RelayDelta(down: down, up: up, peers: Map.of(peers), reset: true);
    }

    final reset = down < _down || up < _up;
    final deltaDown = down < _down ? down : down - _down;
    final deltaUp = up < _up ? up : up - _up;
    final peerDeltas = <String, ByteCounts>{};
    for (final entry in peers.entries) {
      final prev = _peers[entry.key];
      final cur = entry.value;
      final d = (prev == null || cur.down < prev.down)
          ? cur.down
          : cur.down - prev.down;
      final u = (prev == null || cur.up < prev.up) ? cur.up : cur.up - prev.up;
      if (d > 0 || u > 0) peerDeltas[entry.key] = (down: d, up: u);
    }
    final arrivals = allPresent.difference(_present);
    _down = down;
    _up = up;
    _peers = Map.of(peers);
    _present = allPresent;
    return RelayDelta(
      down: deltaDown,
      up: deltaUp,
      peers: peerDeltas,
      arrivals: arrivals,
      reset: reset,
    );
  }

  /// Parses `peerBytes` from a snapshot. Entries without an IP are skipped
  /// and repeated IPs are summed.
  static Map<String, ByteCounts> parsePeerBytes(Object? raw) {
    if (raw is! List) return const {};
    final out = <String, ByteCounts>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final ip = (item['ip'] as String?) ?? '';
      if (ip.isEmpty) continue;
      final d = (item['down'] as num?)?.toInt() ?? 0;
      final u = (item['up'] as num?)?.toInt() ?? 0;
      final prev = out[ip];
      out[ip] = prev == null
          ? (down: d, up: u)
          : (down: prev.down + d, up: prev.up + u);
    }
    return out;
  }
}
