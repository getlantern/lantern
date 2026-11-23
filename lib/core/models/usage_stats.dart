/// The bytes the VPN carried along each path, kept only on this device by
/// radiance (vpn.Usage). Holds byte totals only: no destination, server or
/// time of use.
class UsageStats {
  /// When counting started, or restarted after a reset.
  final DateTime? since;

  /// The calendar month [thisMonth] covers, as YYYY-MM.
  final String month;

  final UsageTotals lifetime;
  final UsageTotals thisMonth;

  /// When the totals were last reset; null if never.
  final DateTime? resetAt;

  const UsageStats({
    required this.since,
    required this.month,
    required this.lifetime,
    required this.thisMonth,
    this.resetAt,
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      since: _parseTime(json['since']),
      month: json['month'] is String ? json['month'] as String : '',
      lifetime: UsageTotals.fromJson(_map(json['lifetime'])),
      thisMonth: UsageTotals.fromJson(_map(json['this_month'])),
      resetAt: _parseTime(json['reset_at']),
    );
  }

  /// [month] as a date on the 1st, or null if it doesn't parse.
  DateTime? get monthStart {
    final parts = month.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (year == null || m == null || !_supportedYear(year)) return null;
    if (m < 1 || m > 12) return null;
    return DateTime(year, m);
  }

  static DateTime? _parseTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final t = DateTime.tryParse(value);
    // Go's zero time, which an unset time marshals to, reads as unknown.
    if (t == null || !_supportedYear(t.year)) return null;
    return t.toLocal();
  }
}

/// The path traffic took. Declared in the order the screen lists them.
enum UsagePath { proxyless, lantern, personal, private, direct }

/// The bytes along each [UsagePath].
class UsageTotals {
  final Map<UsagePath, UsageBytes> _byPath;

  const UsageTotals(this._byPath);

  factory UsageTotals.fromJson(Map<String, dynamic> json) {
    return UsageTotals({
      for (final path in UsagePath.values)
        path: UsageBytes.fromJson(_map(json[path.name])),
    });
  }

  UsageBytes operator [](UsagePath path) => _byPath[path] ?? UsageBytes.zero;

  int get total =>
      UsagePath.values.fold(0, (sum, path) => sum + this[path].total);
}

/// Bytes sent ([up]) and received ([down]) along one path.
class UsageBytes {
  final int up;
  final int down;

  const UsageBytes({required this.up, required this.down});

  static const zero = UsageBytes(up: 0, down: 0);

  factory UsageBytes.fromJson(Map<String, dynamic> json) {
    return UsageBytes(up: _int(json['up']), down: _int(json['down']));
  }

  int get total => up + down;
}

/// Years after Go's zero time and within RFC 3339's four digits.
bool _supportedYear(int year) => year > 1 && year <= 9999;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

int _int(Object? value) {
  if (value is int) return value < 0 ? 0 : value;
  if (value is num) return value < 0 ? 0 : value.toInt();
  return 0;
}
