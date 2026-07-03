import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/referral_attach_response.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/features/plans/plan_item.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';

class PlansListView extends HookConsumerWidget {
  final PlansData data;

  const PlansListView({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referral = ref.watch(referralProvider);
    // Referral codes show the per-plan bonus message; affiliate codes instead
    // show strikethrough discount pricing.
    final showReferralBonus = referral.isReferral;
    final discountPct = referral.isAffiliate ? referral.discountPct : 0;
    final size = MediaQuery.of(context).size;
    final selectedId = useState<String>(
      data.plans.firstWhere((Plan plan) => plan.bestValue == true).id,
    );
    final selectedPlan = data.plans.firstWhere(
      (Plan plan) => plan.id == selectedId.value,
      orElse: () =>
          data.plans.firstWhere((Plan plan) => plan.bestValue == true),
    );
    useEffect(() {
      ref.read(plansProvider.notifier).setSelectedPlan(selectedPlan);
      return null;
    }, [data, selectedId.value]);
    return SizedBox(
      height: context.isSmallDevice ? size.height * 0.21 : null,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: data.plans.length,
        scrollDirection: context.isSmallDevice
            ? Axis.horizontal
            : Axis.vertical,
        padding: EdgeInsets.zero,
        physics: context.isSmallDevice
            ? null
            : const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final item = data.plans[index];
          return PlanItem(
            plan: item,
            planSelected: selectedPlan.id == item.id,
            referralMessage: showReferralBonus
                ? getReferralMessage(item.id)
                : '',
            discountPct: discountPct,
            onPressed: (plans) {
              selectedId.value = plans.id;
            },
          );
        },
      ),
    );
  }
}
