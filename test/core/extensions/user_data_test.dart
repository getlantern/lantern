import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/models/user.dart';

void main() {
  UserDataModel userAt(String level) => UserDataModel(userLevel: level);

  group('UserDataModel.isPro', () {
    test('true for the level the server sends', () {
      expect(userAt('pro').isPro, isTrue);
    });

    // The purchase flow has always lowercased before comparing while the UI did
    // not, so a change in casing upstream would have shown a paying user the
    // free tier while the purchase flow considered them Pro.
    test('is case-insensitive', () {
      expect(userAt('Pro').isPro, isTrue);
      expect(userAt('PRO').isPro, isTrue);
    });

    test('false for every other level', () {
      expect(userAt('expired').isPro, isFalse);
      expect(userAt('initial').isPro, isFalse);
      expect(userAt('').isPro, isFalse);
    });

    // platinum is a valid server-side level that we do not issue yet. Recorded
    // so the day it is issued, this failing expectation is the reminder.
    test('does not yet treat platinum as Pro', () {
      expect(userAt('platinum').isPro, isFalse);
    });
  });

  group('UserDataModel.isExpired', () {
    test('true for expired, case-insensitively', () {
      expect(userAt('expired').isExpired, isTrue);
      expect(userAt('Expired').isExpired, isTrue);
    });

    test('false for pro and for unset', () {
      expect(userAt('pro').isExpired, isFalse);
      expect(userAt('').isExpired, isFalse);
    });
  });

  test('isPro and isExpired are never both true', () {
    for (final level in ['pro', 'expired', 'initial', 'platinum', '']) {
      final user = userAt(level);
      expect(user.isPro && user.isExpired, isFalse, reason: 'level=$level');
    }
  });
}
