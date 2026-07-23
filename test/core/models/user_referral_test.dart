import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/models/user.dart';

void main() {
  group('ReferralModel', () {
    test('parses and serializes referral data', () {
      final referral = ReferralModel.fromJson({
        'userId': 123,
        'converted': true,
        'convertedAt': 456,
        'bonusDaysEarned': 30,
      });

      expect(referral.userId, '123');
      expect(referral.converted, isTrue);
      expect(referral.convertedAt, 456);
      expect(referral.bonusDaysEarned, 30);
      expect(referral.toJson(), {
        'userId': '123',
        'converted': true,
        'convertedAt': 456,
        'bonusDaysEarned': 30,
      });
    });

    test('treats unexpected converted values as false', () {
      expect(ReferralModel.fromJson({'converted': 'true'}).converted, isFalse);
      expect(ReferralModel.fromJson({'converted': 1}).converted, isFalse);
    });
  });

  group('UserDataModel referrals', () {
    test('parses referral maps and ignores malformed list entries', () {
      final user = UserDataModel.fromJson({
        'referrals': [
          {'userId': 'converted', 'converted': true, 'bonusDaysEarned': 30},
          'not-a-map',
          {'userId': 'pending', 'converted': false},
        ],
      });

      expect(user.referrals, hasLength(2));
      expect(user.referrals.map((referral) => referral.userId), [
        'converted',
        'pending',
      ]);
    });

    test('totals bonus time from converted referrals only', () {
      const user = UserDataModel(
        referrals: [
          ReferralModel(converted: true, bonusDaysEarned: 30),
          ReferralModel(converted: false, bonusDaysEarned: 30),
          ReferralModel(converted: true, bonusDaysEarned: 60),
        ],
      );

      expect(user.referralBonusDays, 90);
      expect(user.referralBonusMonths, 3);
    });
  });
}
