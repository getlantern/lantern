import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/referral_attach_response.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/plan_data.dart';

part 'referral_notifier.g.dart';

@Riverpod(keepAlive: true)
class ReferralNotifier extends _$ReferralNotifier {
  @override
  ReferralAttachV2Response? build() => null;

  /// Applies a referral code via the V2 endpoint. On success the returned
  /// discounted plans are pushed into [plansProvider] so the plans UI updates
  /// immediately, the response becomes the notifier state, and it is returned
  /// to the caller.
  Future<Either<Failure, ReferralAttachV2Response>> applyReferralCodeV2(
    String code,
  ) async {
    final result = await ref
        .read(lanternServiceProvider)
        .attachReferralCodeV2(code);
    if (result.isRight()) {
      final response = result.getRight().toNullable();
      state = response;
      // plansData is only present for the affiliate flow; the referral flow
      // has no discounted plans to push into the plans UI.
      final plansData = response?.plansData;
      if (plansData != null) {
        ref.read(plansProvider.notifier).updatePlans(plansData);
        final plans = plansData.plans;
        if (plans.isNotEmpty) {
          // The backend may not flag a best-value plan (and discounted sets
          // may omit it entirely), so fall back to the first plan rather than
          // let firstWhere throw and crash the apply-code flow.
          final defaultPlan = plans.firstWhere(
            (Plan plan) => plan.bestValue == true,
            orElse: () => plans.first,
          );
          ref.read(plansProvider.notifier).setSelectedPlan(defaultPlan);
        }
      }
    }
    return result;
  }

  void resetReferral() => state = null;
}
