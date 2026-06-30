import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/referral_attach_response.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'referral_notifier.g.dart';

@Riverpod(keepAlive: true)
class ReferralNotifier extends _$ReferralNotifier {
  /// The applied V2 referral/affiliate response, populated on a successful
  /// [applyReferralCodeV2]. Drives the affiliate discount UI (code chip,
  /// "X% discount applied" banner, strikethrough pricing). Null when no V2
  /// code is applied. The `state` bool remains the simple applied/not flag
  /// that existing widgets watch.
  ReferralAttachV2Response? appliedReferral;

  bool get isAffiliateApplied => appliedReferral?.isAffiliate ?? false;

  @override
  bool build() {
    return false;
  }

  Future<Either<Failure, String>> applyReferralCode(String code) async {
    final result =
        await ref.read(lanternServiceProvider).attachReferralCode(code);
    if (result.isRight()) {
      state = true;
    }
    return result;
  }

  /// Applies a referral code via the V2 endpoint. On success the returned
  /// discounted plans are pushed into [plansProvider] so the plans UI updates
  /// immediately, and the resulting response is returned to the caller.
  Future<Either<Failure, ReferralAttachV2Response>> applyReferralCodeV2(
    String code,
  ) async {
    final result =
        await ref.read(lanternServiceProvider).attachReferralCodeV2(code);
    if (result.isRight()) {
      final response = result.getRight().toNullable();
      appliedReferral = response;
      state = true;
      if (response != null) {
        ref.read(plansProvider.notifier).updatePlans(response.plansData);
      }
    }
    return result;
  }

  void resetReferral() {
    appliedReferral = null;
    state = false;
  }
}
