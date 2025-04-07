import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class PlansListView extends StatelessWidget {
  const PlansListView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final finalSize = (width * 0.5) - (defaultSize * 3);
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        badges.Badge(
          badgeAnimation: badges.BadgeAnimation.scale(
            toAnimate: false,
          ),
          position: badges.BadgePosition.custom(
            top: -15,
            start: (finalSize - 10),
          ),
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
            'Best Value!',
            style: textTheme.labelMedium,
          ),
          child: GestureDetector(
            onTap: () {
              appRouter.push(AddEmail());
            },
            child: AnimatedContainer(
              margin: EdgeInsets.only(bottom: defaultSize),
              padding:
                  EdgeInsets.symmetric(horizontal: defaultSize, vertical: 10),
              duration: Duration(milliseconds: 300),
              decoration: selectedDecoration,
              child: Row(
                children: <Widget>[
                  Text(
                    'Two Year Plan',
                    style: textTheme.titleMedium,
                  ),
                  Spacer(),
                  Column(
                    children: <Widget>[
                      Text(
                        '\$87.00',
                        style: textTheme.titleMedium!.copyWith(
                          color: AppColors.blue7,
                        ),
                      ),
                      Text(
                        '\$3.64/month',
                        style: textTheme.labelMedium!.copyWith(
                          color: AppColors.gray7,
                        ),
                      ),
                    ],
                  ),
                  Radio(
                    value: true,
                    groupValue: false,
                    fillColor: WidgetStatePropertyAll(AppColors.gray9),
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedContainer(
          margin: EdgeInsets.only(bottom: defaultSize),
          padding: EdgeInsets.symmetric(horizontal: defaultSize, vertical: 10),
          duration: Duration(milliseconds: 300),
          decoration: unselectedDecoration,
          child: Row(
            children: <Widget>[
              Text(
                'Two Year Plan',
                style: textTheme.titleMedium,
              ),
              Spacer(),
              Column(
                children: <Widget>[
                  Text(
                    '\$87.00',
                    style: textTheme.titleMedium!.copyWith(
                      color: AppColors.blue7,
                    ),
                  ),
                  Text(
                    '\$3.64/month',
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                    ),
                  ),
                ],
              ),
              Radio(
                value: true,
                groupValue: false,
                fillColor: WidgetStatePropertyAll(AppColors.gray9),
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        AnimatedContainer(
          padding: EdgeInsets.symmetric(horizontal: defaultSize, vertical: 10),
          duration: Duration(milliseconds: 300),
          decoration: unselectedDecoration,
          child: Row(
            children: <Widget>[
              Text(
                'Two Year Plan',
                style: textTheme.titleMedium,
              ),
              Spacer(),
              Column(
                children: <Widget>[
                  Text(
                    '\$87.00',
                    style: textTheme.titleMedium!.copyWith(
                      color: AppColors.blue7,
                    ),
                  ),
                  Text(
                    '\$3.64/month',
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                    ),
                  ),
                ],
              ),
              Radio(
                value: true,
                groupValue: false,
                fillColor: WidgetStatePropertyAll(AppColors.gray9),
                onChanged: (value) {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration get selectedDecoration {
    return BoxDecoration(
      color: AppColors.blue1,
      border: Border.all(color: AppColors.blue7, width: 3),
      borderRadius: BorderRadius.circular(16),
    );
  }

  BoxDecoration get unselectedDecoration {
    return BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.gray3, width: 1.5),
      borderRadius: BorderRadius.circular(16),
    );
  }
}
