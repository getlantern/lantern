import 'package:lantern/core/models/user.dart';

extension UserDataProX on UserDataModel {
  /// The one client-side Pro check. `userLevel` is the server's entitlement of
  /// record (pro_users.level, via /user-data), so nothing else should re-derive
  /// it — duplicate copies of this comparison are how the UI and the purchase
  /// flow drifted apart on casing.
  bool get isPro => _level == 'pro';

  bool get isExpired => _level == 'expired';

  /// Folded because the purchase flow has always compared case-insensitively.
  /// Matching that means a casing change upstream cannot silently drop someone
  /// to the free UI.
  String get _level => userLevel.toLowerCase();

  /// Total bonus days earned from converted referrals.
  int get referralBonusDays => referrals
      .where((r) => r.converted)
      .fold(0, (total, r) => total + r.bonusDaysEarned);

  /// Bonus months earned from referrals (30 days == 1 month).
  int get referralBonusMonths => referralBonusDays ~/ 30;
}
