import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/utils/decoration.dart';

import '../../core/common/common.dart';

class PlanItem extends StatelessWidget {
  final Plan plan;
  final bool planSelected;
  final Function(Plan plans) onPressed;

  const PlanItem({
    super.key,
    required this.plan,
    required this.planSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final finalSize = (width * 0.5) - (defaultSize * 3);
    return badges.Badge(
      showBadge: plan.bestValue ?? false,
      badgeAnimation: badges.BadgeAnimation.scale(
        toAnimate: false,
      ),
      position: badges.BadgePosition.custom(start: (finalSize - 10), top: 6),
      // Adjust values as needed
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.square,
        borderSide: BorderSide(
          color: AppColors.yellow4,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        badgeColor: AppColors.yellow3,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      badgeContent: Text(
        'best_value'.i18n,
        style: textTheme.labelMedium,
      ),
      child: GestureDetector(
        onTap: () {
          onPressed.call(plan);
        },
        child: AnimatedContainer(
          margin: EdgeInsets.only(
            top: 20,
          ),
          padding: EdgeInsets.symmetric(horizontal: defaultSize, vertical: 12),
          duration: Duration(milliseconds: 300),
          decoration: planSelected ? selectedDecoration : unselectedDecoration,
          child: Row(
            children: <Widget>[
              Text(
                plan.description,
                style: textTheme.titleMedium,
              ),
              Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    plan.formattedYearlyPrice,
                    style: textTheme.titleMedium!.copyWith(
                      color: AppColors.blue7,
                    ),
                  ),
                  Text(
                    '${plan.formattedMonthlyPrice}/month',
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                    ),
                  ),
                ],
              ),
              Radio(
                value: true,
                groupValue: planSelected,
                fillColor: WidgetStatePropertyAll(AppColors.gray9),
                onChanged: (value) {
                  onPressed.call(plan);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
