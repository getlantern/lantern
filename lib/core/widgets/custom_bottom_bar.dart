import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_keys.dart';
import 'package:lantern/core/common/colors.dart';
import 'package:lantern/core/common/dimens.dart';
import 'package:lantern/core/common/image_paths.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/widgets/custom_bottom_item.dart';

const TAB_VPN = 'vpn';
const TAB_ACCOUNT = 'account';
const TAB_DEVELOPER = 'developer';

class CustomBottomBar extends StatelessWidget {
  final String selectedTab;
  final bool isDevelop;

  // final bool isTesting;

  const CustomBottomBar({
    required this.selectedTab,
    required this.isDevelop,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final indexToTab = <int, String>{};
    final tabToIndex = <String, int>{};

    var nextIndex = 0;
    indexToTab[nextIndex] = TAB_VPN;
    tabToIndex[TAB_VPN] = nextIndex++;
    indexToTab[nextIndex] = TAB_ACCOUNT;
    tabToIndex[TAB_ACCOUNT] = nextIndex++;
    if (isDevelop) {
      /// Just to be safe here
      /// Dev tab should not be visible in release mode
      if (!kReleaseMode) {
        indexToTab[nextIndex] = TAB_DEVELOPER;
        tabToIndex[TAB_DEVELOPER] = nextIndex++;
      }
    }
    final currentIndex = tabToIndex[selectedTab] ?? tabToIndex[TAB_VPN]!;
    return BottomNavigationBar(
      currentIndex: currentIndex,
      elevation: 0.0,
      unselectedFontSize: 0,
      selectedFontSize: 0,
      showSelectedLabels: false,
      type: BottomNavigationBarType.fixed,
      items: buildItems(
        context,
        indexToTab,
        tabToIndex,
        currentIndex,
        false,
        false,
        true,
        isDevelop,
        '',
      ),
    );
  }

  List<BottomNavigationBarItem> buildItems(
    BuildContext context,
    Map<int, String> indexToTab,
    Map<String, int> tabToIndex,
    int currentIndex,
    bool chatEnabled,
    bool replicaEnabled,
    bool hasBeenOnboarded,
    bool isDevelop,
    String replicaAddr,
  ) {
    final items = <BottomNavigationBarItem>[];
    String vpnStatus = 'Disconnected';
    items.add(
      BottomNavigationBarItem(
        icon: CustomBottomBarItem(
          name: TAB_VPN,
          currentTabIndex: currentIndex,
          indexToTab: indexToTab,
          tabToIndex: tabToIndex,
          label: 'VPN'.i18n,
          icon: ImagePaths.key,
          labelWidget: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4.0),
            child: CircleAvatar(
              maxRadius: activeIconSize - 4,
              backgroundColor: (vpnStatus.toLowerCase() ==
                          'Disconnecting'.i18n.toLowerCase() ||
                      vpnStatus == 'connected'.i18n.toLowerCase())
                  ? indicatorGreen
                  : indicatorRed,
            ),
          ),
        ),
        label: '',
        tooltip: 'VPN'.i18n,
      ),
    );

    items.add(
      BottomNavigationBarItem(
        icon: CustomBottomBarItem(
          key: AppKeys.bottom_bar_account_tap_key,
          name: TAB_ACCOUNT,
          currentTabIndex: currentIndex,
          indexToTab: indexToTab,
          tabToIndex: tabToIndex,
          label: 'Account'.i18n,
          icon: ImagePaths.account,
        ),
        label: '',
        tooltip: 'Account'.i18n,
      ),
    );

    if (isDevelop) {
      items.add(
        BottomNavigationBarItem(
          icon: CustomBottomBarItem(
            key: AppKeys.bottom_bar_developer_tap_key,
            name: TAB_DEVELOPER,
            currentTabIndex: currentIndex,
            indexToTab: indexToTab,
            tabToIndex: tabToIndex,
            label: 'Developer'.i18n,
            icon: ImagePaths.devices,
          ),
          label: '',
          tooltip: 'Developer'.i18n,
        ),
      );
    }

    return items;
  }
}

///Change notifier used the bottom bar
///update tap when user click on the bottom bar
class BottomBarChangeNotifier extends ChangeNotifier {
  String _currentIndex = TAB_VPN;

  String get currentIndex => _currentIndex;

  void setCurrentIndex(String tabName) {
    _currentIndex = tabName;
    notifyListeners();
  }
}
