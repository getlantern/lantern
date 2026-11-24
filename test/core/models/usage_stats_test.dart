import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/usage_stats.dart';

void main() {
  test('parses radiance vpn.Usage JSON', () {
    final stats = UsageStats.fromJson(
      jsonDecode('''
{
  "since": "2026-11-03T08:15:00Z",
  "month": "2026-11",
  "lifetime": {
    "proxyless": {"up": 10, "down": 20},
    "personal": {"up": 1, "down": 2},
    "private": {"up": 3, "down": 4},
    "lantern": {"up": 100, "down": 200},
    "direct": {"up": 5, "down": 6}
  },
  "this_month": {
    "proxyless": {"up": 7, "down": 8},
    "personal": {"up": 0, "down": 0},
    "private": {"up": 0, "down": 0},
    "lantern": {"up": 9, "down": 10},
    "direct": {"up": 0, "down": 1}
  },
  "reset_at": "2026-11-03T08:15:00Z"
}
'''),
    );
    expect(stats.since, DateTime.utc(2026, 11, 3, 8, 15).toLocal());
    expect(stats.month, '2026-11');
    expect(stats.monthStart, DateTime(2026, 11));
    expect(stats.resetAt, isNotNull);

    expect(stats.lifetime[UsagePath.proxyless].up, 10);
    expect(stats.lifetime[UsagePath.proxyless].down, 20);
    expect(stats.lifetime[UsagePath.personal].total, 3);
    expect(stats.lifetime[UsagePath.private].total, 7);
    expect(stats.lifetime[UsagePath.servers].total, 300);
    expect(stats.lifetime[UsagePath.direct].total, 11);
    expect(stats.lifetime.total, 30 + 3 + 7 + 300 + 11);

    expect(stats.thisMonth[UsagePath.proxyless].total, 15);
    expect(stats.thisMonth[UsagePath.servers].total, 19);
    expect(stats.thisMonth.total, 15 + 19 + 1);
  });

  test('missing reset_at, paths and fields read as never and zero', () {
    final stats = UsageStats.fromJson({
      'since': '2026-11-01T00:00:00Z',
      'month': '2026-11',
      'lifetime': {
        'lantern': {'up': 5},
      },
    });
    expect(stats.resetAt, isNull);
    expect(stats.lifetime[UsagePath.servers].up, 5);
    expect(stats.lifetime[UsagePath.servers].down, 0);
    expect(stats.lifetime[UsagePath.proxyless].total, 0);
    expect(stats.thisMonth.total, 0);
  });

  test("Go's zero time and a bad month parse as unknown", () {
    final stats = UsageStats.fromJson({
      'since': '0001-01-01T00:00:00Z',
      'month': 'garbage',
    });
    expect(stats.since, isNull);
    expect(stats.monthStart, isNull);
  });

  test('a month that is not a string, or an unsupported year, is unknown', () {
    expect(UsageStats.fromJson({'month': 202611}).month, '');
    expect(UsageStats.fromJson({'month': 202611}).monthStart, isNull);
    expect(UsageStats.fromJson({'month': '0000-11'}).monthStart, isNull);
    expect(UsageStats.fromJson({'month': '12026-11'}).monthStart, isNull);
    expect(UsageStats.fromJson({'month': '2026-13'}).monthStart, isNull);
    expect(
      UsageStats.fromJson({'since': '+12026-01-01T00:00:00Z'}).since,
      isNull,
    );
  });
}
