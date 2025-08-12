import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/features/plans/plan_item.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';

class PlansListView extends HookConsumerWidget {
  final PlansData data;
  final Function(Plan plans) onPlanSelected;

  const PlansListView({
    super.key,
    required this.data,
    required this.onPlanSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final plan = useState<Plan>(
        data.plans.firstWhere((Plan plan) => plan.bestValue == true));
    ref.read(plansNotifierProvider.notifier).setSelectedPlan(plan.value);
    return SizedBox(
      height: context.isSmallDevice ? size.height * 0.21 : null,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: data.plans.length,
        scrollDirection:
            context.isSmallDevice ? Axis.horizontal : Axis.vertical,
        padding: EdgeInsets.zero,
        physics:
            context.isSmallDevice ? null : const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final item = data.plans[index];
          return PlanItem(
            plan: item,
            planSelected: plan.value.id == item.id,
            onPressed: (plans) {
              plan.value = plans;
              ref.read(plansNotifierProvider.notifier).setSelectedPlan(plans);
            },
          );
        },
      ),
    );
  }
}
