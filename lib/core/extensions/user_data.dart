import 'package:lantern/core/models/user.dart';

extension UserDataProX on UserDataModel {
  bool get isPro => userLevel == 'pro';

  /// Total bonus days earned from converted referrals.
  int get referralBonusDays => referrals
      .where((r) => r.converted)
      .fold(0, (total, r) => total + r.bonusDaysEarned);

  /// Bonus months earned from referrals (30 days == 1 month).
  int get referralBonusMonths => referralBonusDays ~/ 30;
}
