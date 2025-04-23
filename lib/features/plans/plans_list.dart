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

// Widget _buildSmallItem({bool isBestValue = false}) {
//   final textTheme = Theme.of(context).textTheme;
//   return badges.Badge(
//     showBadge: isBestValue,
//     badgeAnimation: badges.BadgeAnimation.scale(
//       toAnimate: false,
//     ),
//     position: badges.BadgePosition.custom(start: 28, top: 5),
//     badgeStyle: badges.BadgeStyle(
//       shape: badges.BadgeShape.square,
//       borderSide: BorderSide(
//         color: AppColors.yellow4,
//         width: 1,
//       ),
//       borderRadius: BorderRadius.circular(16),
//       badgeColor: AppColors.yellow3,
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//     ),
//     badgeContent: Text(
//       'Best Value!',
//       style: textTheme.labelMedium,
//     ),
//     child: GestureDetector(
//       onTap: () {
//         appRouter.push(AddEmail());
//       },
//       child: AnimatedContainer(
//         margin: EdgeInsets.only(top: 20, right: defaultSize),
//         padding:
//             EdgeInsets.only(left: defaultSize, right: 8, top: 10, bottom: 10),
//         duration: Duration(milliseconds: 300),
//         decoration: isBestValue ? selectedDecoration : unselectedDecoration,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.only(top: 4),
//                   child: Text(
//                     '2 Year ',
//                     style: textTheme.titleMedium,
//                   ),
//                 ),
//                 SizedBox(width: defaultSize),
//                 Radio(
//                   value: true,
//                   groupValue: isBestValue,
//                   visualDensity: VisualDensity.compact,
//                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                   fillColor: WidgetStatePropertyAll(AppColors.gray9),
//                   onChanged: (value) {},
//                 )
//               ],
//             ),
//             Text(
//               '\$99.99',
//               style: textTheme.titleMedium!.copyWith(
//                 color: AppColors.blue7,
//               ),
//             ),
//             Text(
//               '\$4.17/month',
//               style: textTheme.labelMedium!.copyWith(
//                 color: AppColors.gray7,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }
}
