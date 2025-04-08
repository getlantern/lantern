import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/screen_utils.dart';

class PlansListView extends StatefulWidget {
  const PlansListView({super.key});

  @override
  State<PlansListView> createState() => _PlansListViewState();
}

class _PlansListViewState extends State<PlansListView> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      height: context.isSmallDevice ? size.height * 0.21 :null,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: 3,
        scrollDirection:
            context.isSmallDevice ? Axis.horizontal : Axis.vertical,
        padding: EdgeInsets.zero,
        physics:
            context.isSmallDevice ? null : const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          if (context.isSmallDevice) {
            return _buildSmallItem(isBestValue: index == 0);
          }
          return _buildItem(isBestValue: index == 0);
        },
      ),
    );
  }

  Widget _buildSmallItem({bool isBestValue = false}) {
    final textTheme = Theme.of(context).textTheme;
    return badges.Badge(
      showBadge: isBestValue,
      badgeAnimation: badges.BadgeAnimation.scale(
        toAnimate: false,
      ),
      position: badges.BadgePosition.custom(start: 28, top: 5),
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.square,
        borderSide: BorderSide(
          color: AppColors.yellow4,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        badgeColor: AppColors.yellow3,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          margin: EdgeInsets.only(top: 20, right: defaultSize),
          padding: EdgeInsets.only(left: defaultSize, right: 8,top: 10,bottom: 10),
          duration: Duration(milliseconds: 300),
          decoration: isBestValue ? selectedDecoration : unselectedDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '2 Year ',
                      style: textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(width: defaultSize),
                  Radio(
                    value: true,
                    groupValue: isBestValue,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    fillColor: WidgetStatePropertyAll(AppColors.gray9),
                    onChanged: (value) {},
                  )
                ],
              ),
              Text(
                '\$99.99',
                style: textTheme.titleMedium!.copyWith(
                  color: AppColors.blue7,
                ),
              ),
              Text(
                '\$4.17/month',
                style: textTheme.labelMedium!.copyWith(
                  color: AppColors.gray7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem({bool isBestValue = false}) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final finalSize = (width * 0.5) - (defaultSize * 3);
    return badges.Badge(
      showBadge: isBestValue,
      badgeAnimation: badges.BadgeAnimation.scale(
        toAnimate: false,
      ),
      position: badges.BadgePosition.custom(
        start: (finalSize - 10),
        top: 6
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
          margin: EdgeInsets.only(
            top: 20,
          ),
          padding: EdgeInsets.symmetric(horizontal: defaultSize, vertical: 12),
          duration: Duration(milliseconds: 300),
          decoration: isBestValue ? selectedDecoration : unselectedDecoration,
          child: Row(
            children: <Widget>[
              Text(
                'Two Year Plan',
                style: textTheme.titleMedium,
              ),
              Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
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
