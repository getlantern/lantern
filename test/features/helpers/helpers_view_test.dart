import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';

void main() {
  test('parses a full view', () {
    final v = HelpersView.fromJson({
      'unlocked': true,
      'my_name': 'Sara',
      'invites': [
        {
          'id': 'i1',
          'state': 'claimed',
          'expires_unix': 1800000000,
          'code': '1234',
          'volunteer_name': 'Ali',
        },
        {
          'id': 'i2',
          'state': 'pending',
          'link': 'https://lantern.io/help/#x',
          'expires_unix': 1800000000,
          'inviter_name': 'S. from work',
        },
      ],
      'claims': [
        {'id': 'c1', 'code': '9876', 'expires_unix': 1800000000},
        {
          'id': 'c2',
          'code': '1111',
          'expires_unix': 1800000000,
          'provisional': true,
        },
      ],
      'helpers': [
        {
          'pairing_id': 'p1',
          'name': 'Ali',
          'online': true,
          'since_unix': 1700000000,
        },
      ],
      'helping': [
        {'pairing_id': 'p2', 'name': 'Sara', 'since_unix': 1700000000},
      ],
      'activity': {
        'day': '2026-10-23',
        'active_seconds': 3600,
        'relayed_bytes': 42,
      },
      'new_helping': true,
    });
    expect(v.unlocked, isTrue);
    expect(v.invites.first.claimed, isTrue);
    expect(v.invites.last.link, 'https://lantern.io/help/#x');
    expect(v.invites.last.inviterName, 'S. from work');
    expect(v.invites.first.inviterName, '');
    expect(v.claims.first.code, '9876');
    expect(v.claims.first.provisional, isFalse);
    expect(v.claims.last.provisional, isTrue);
    expect(v.helpers.single.online, isTrue);
    expect(v.helping.single.name, 'Sara');
    expect(v.activity!.activeSeconds, 3600);
    expect(v.newHelping, isTrue);
    expect(v.needsPolling, isTrue);
  });

  test('a malformed entry is skipped, not fatal', () {
    final v = HelpersView.fromJson({
      'unlocked': true,
      'helpers': [
        'junk',
        {
          'pairing_id': 'p1',
          'name': 7,
          'online': 'yes',
          'since_unix': '1700000000',
        },
      ],
      'invites': 'not a list',
    });
    expect(v.helpers.single.pairingId, 'p1');
    expect(v.helpers.single.name, '');
    expect(v.helpers.single.online, isFalse);
    expect(v.helpers.single.sinceUnix, 1700000000);
    expect(v.invites, isEmpty);
    expect(v.needsPolling, isFalse);
  });
}
