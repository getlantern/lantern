import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/user.dart';

void main() {
  group('userDataReflectsPurchase', () {
    test('free user is never a completed purchase', () {
      const userData = UserDataModel(userLevel: '', expiration: 0);
      expect(userDataReflectsPurchase(userData, null), isFalse);
      expect(userDataReflectsPurchase(userData, 0), isFalse);
    });

    test('pro user counts when no prior expiration is known', () {
      const userData = UserDataModel(userLevel: 'pro', expiration: 1789689600);
      expect(userDataReflectsPurchase(userData, null), isTrue);
    });

    test('first purchase: expiration advances past 0', () {
      const userData = UserDataModel(userLevel: 'pro', expiration: 1789689600);
      expect(userDataReflectsPurchase(userData, 0), isTrue);
    });

    test(
      'renewal: already-pro user with unchanged expiration is NOT a '
      'completed purchase',
      () {
        // Regression for the Alipay renewal case: the account was already pro
        // (expiring 2026-09-18) and the new purchase had not been credited, so
        // isPro alone must not confirm the renewal.
        const userData = UserDataModel(
          userLevel: 'pro',
          expiration: 1789689600,
        );
        expect(userDataReflectsPurchase(userData, 1789689600), isFalse);
      },
    );

    test('renewal: extended expiration is a completed purchase', () {
      const userData = UserDataModel(userLevel: 'pro', expiration: 1852761600);
      expect(userDataReflectsPurchase(userData, 1789689600), isTrue);
    });
  });
}
