import 'package:flutter/material.dart';
import 'package:lantern/core/common/asset_image.dart';
import 'package:lantern/core/common/colors.dart';
import 'package:lantern/core/common/dimens.dart';
import 'package:lantern/core/common/ink_well.dart';
import 'package:lantern/core/common/rounded_rectangle_border.dart';
import 'package:lantern/core/common/text.dart';
import 'package:lantern/core/common/text_styles.dart';

class CustomBottomBarItem extends StatelessWidget {
  const CustomBottomBarItem({
    required this.name,
    required this.currentTabIndex,
    required this.indexToTab,
    required this.tabToIndex,
    required this.icon,
    required this.label,
    this.labelWidget,
    this.addBadge = defaultAddBadge,
    Key? key,
  }) : super(key: key);

  final String name;
  final int currentTabIndex;
  final Map<int, String> indexToTab;
  final Map<String, int> tabToIndex;
  final String label;
  final String icon;
  final Widget? labelWidget;
  final Widget Function(Widget) addBadge;

  int get totalTabs => tabToIndex.length;

  int get tabIndex => tabToIndex[name]!;

  bool get active => currentTabIndex == tabIndex;

  static Widget defaultAddBadge(Widget child) => child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      color: transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.tight,
            flex: 1,
            child: CInkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(
                    currentTabIndex != 0 ? borderRadius : 0,
                  ),
                  topEnd: Radius.circular(
                    currentTabIndex != totalTabs ? borderRadius : 0,
                  ),
                ),
              ),
              onTap: (() {
                /// notifiy the bottom listener to update UI
                //sessionModel.setSelectedTab(context, name);
              }),
              child: Container(
                decoration: ShapeDecoration(
                  color: tabIndex == currentTabIndex
                      ? selectedTabColor
                      : unselectedTabColor,
                  shape: CRoundedRectangleBorder(
                    topSide: tabIndex == currentTabIndex
                        ? null
                        : BorderSide(
                            color: borderColor,
                            width: 1,
                          ),
                    endSide: currentTabIndex == tabIndex + 1
                        ? BorderSide(
                            color: borderColor,
                            width: 1,
                          )
                        : null,
                    startSide: currentTabIndex == tabIndex - 1
                        ? BorderSide(
                            color: borderColor,
                            width: 1,
                          )
                        : null,
                    topStartCornerSide: BorderSide(
                      color: currentTabIndex == tabIndex - 1
                          ? borderColor
                          : Colors.white,
                    ),
                    topEndCornerSide: BorderSide(
                      color: currentTabIndex == tabIndex + 1
                          ? borderColor
                          : Colors.white,
                    ),
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: Radius.circular(
                        currentTabIndex == tabIndex - 1 ? borderRadius : 0,
                      ),
                      topEnd: Radius.circular(
                        currentTabIndex == tabIndex + 1 ? borderRadius : 0,
                      ),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: 12,
                    bottom: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: addBadge(
                          CAssetImage(
                            path: icon,
                            color: active
                                ? selectedTabIconColor
                                : unselectedTabIconColor,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CText(
                            label,
                            style: tsFloatingLabel.copiedWith(
                              color: active ? black : grey5,
                            ),
                          ),
                          labelWidget ?? const SizedBox(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
