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

  test('waiting claims are sent, unexpired and have a code', () {
    const v = HelpersView(
      claims: [
        HelperClaimView(id: 'live', code: '1234', expiresUnix: 200),
        HelperClaimView(id: 'expired', code: '1234', expiresUnix: 100),
        HelperClaimView(
          id: 'unsent',
          code: '1234',
          expiresUnix: 200,
          provisional: true,
        ),
        HelperClaimView(id: 'nocode', code: '', expiresUnix: 200),
      ],
    );
    expect(v.waitingClaims(100).map((c) => c.id), ['live']);
  });

  group('per-friend selection', () {
    const tag = 'helper-0123456789ab';

    test('an inviter row carries its outbound tag', () {
      final v = HelpersView.fromJson({
        'helpers': [
          {
            'pairing_id': 'p1',
            'name': 'Ali',
            'online': true,
            'outbound_tag': tag,
          },
          {'pairing_id': 'p2', 'name': 'Bo'},
        ],
      });
      expect(v.helpers[0].outboundTag, tag);
      expect(v.helpers[1].outboundTag, isEmpty);
      expect(v.helperByTag(tag)?.name, 'Ali');
      expect(v.helperByTag(''), isNull);
      expect(v.helperByTag('helper-ffffffffffff'), isNull);
    });

    test('selectable needs a tag, online and a live route', () {
      const ali = HelperPairingView(
        pairingId: 'p1',
        online: true,
        outboundTag: tag,
      );
      const direct = {tag: PersonalProxyStatus(direct: true)};
      const rooms = {tag: PersonalProxyStatus(rooms: true)};
      const dead = {tag: PersonalProxyStatus()};
      expect(ali.selectable(direct), isTrue);
      expect(ali.selectable(rooms), isTrue);
      expect(ali.selectable(dead), isFalse);
      expect(
        ali.selectable(const {}),
        isFalse,
        reason: 'radiance has no route',
      );

      const offline = HelperPairingView(pairingId: 'p1', outboundTag: tag);
      expect(offline.selectable(direct), isFalse);
      const noTag = HelperPairingView(pairingId: 'p1', online: true);
      expect(noTag.selectable(direct), isFalse);
      expect(noTag.selectable(null), isFalse);
    });

    test('with no status from radiance (VPN off), online decides alone', () {
      const ali = HelperPairingView(
        pairingId: 'p1',
        online: true,
        outboundTag: tag,
      );
      const bo = HelperPairingView(pairingId: 'p2', outboundTag: tag);
      expect(ali.selectable(null), isTrue);
      expect(bo.selectable(null), isFalse);
    });

    test("parses the status op's answer by tag", () {
      final all = PersonalProxyStatus.parseAll({
        'statuses': [
          {'tag': tag, 'direct': true, 'rooms': false},
          {'tag': 'helper-ba9876543210', 'rooms': true},
          {'direct': true},
          'junk',
        ],
      });
      expect(all.keys, [tag, 'helper-ba9876543210']);
      expect(all[tag]!.direct, isTrue);
      expect(all['helper-ba9876543210']!.live, isTrue);
      expect(PersonalProxyStatus.parseAll(const {}), isEmpty);
    });
  });
}
