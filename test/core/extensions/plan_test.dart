import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/models/user.dart';

void main() {
  // Mirrors IsoDateFormatter._formatDate rather than hard-coding a date, so the
  // expectation holds in any timezone — toDate() converts from UTC to local.
  String formattedLocal(int epochSeconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return '$mm/$dd/$yy';
  }

  // Distinct dates so the assertion proves *which* branch ran: the expired
  // branch formats lastExpiredOn, the fall-through formats expiration.
  const lastExpiredOn = 1767225600; // 2026-01-01 UTC
  const expiration = 1798761600; // 2027-01-01 UTC

  group('UserDataModel.toDate() expired branch', () {
    // toDate() used to compare userLevel to 'expired' case-sensitively, so a
    // mixed-case level fell through and reported the expiration date as though
    // the plan were still active.
    test('takes the expired branch for a mixed-case level', () {
      final date = UserDataModel(
        userLevel: 'Expired',
        lastExpiredOn: lastExpiredOn,
        expiration: expiration,
      ).toDate();

      expect(date, contains(formattedLocal(lastExpiredOn)));
      expect(date, isNot(contains(formattedLocal(expiration))));
    });

    test('still takes it for the level the server actually sends', () {
      final date = UserDataModel(
        userLevel: 'expired',
        lastExpiredOn: lastExpiredOn,
        expiration: expiration,
      ).toDate();

      expect(date, contains(formattedLocal(lastExpiredOn)));
    });

    test('reports N/A when there is no expiry timestamp to format', () {
      final date = UserDataModel(
        userLevel: 'Expired',
        lastExpiredOn: 0,
        expiration: expiration,
      ).toDate();

      expect(date, 'N/A');
    });
  });

  group('UserDataModel.extendedExpirationDate', () {
    const endAt = 1783036800; // 2026-07-03 UTC, between endAt and expiration

    UserDataModel user({
      String userLevel = 'pro',
      int expiration = expiration,
      bool autoRenew = true,
      int endAt = endAt,
    }) => UserDataModel(
      userLevel: userLevel,
      expiration: expiration,
      subscriptionData: SubscriptionDataModel(
        autoRenew: autoRenew,
        endAt: endAt,
      ),
    );

    test('formats the account expiration when it extends past endAt', () {
      expect(user().extendedExpirationDate, formattedLocal(expiration));
    });

    test('is null when the account is expired', () {
      expect(user(userLevel: 'expired').extendedExpirationDate, isNull);
    });

    test('is null when the subscription is not auto-renewing', () {
      expect(user(autoRenew: false).extendedExpirationDate, isNull);
    });

    test('is null when the subscription has no endAt', () {
      expect(user(endAt: 0).extendedExpirationDate, isNull);
    });

    test('is null when expiration does not extend past endAt', () {
      expect(user(expiration: endAt).extendedExpirationDate, isNull);
    });

    test('is null instead of throwing for an out-of-range expiration', () {
      expect(user(expiration: 9000000000000000).extendedExpirationDate, isNull);
    });
  });
}
