import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/base_screen.dart';

enum _Social {
  facebook,
  x,
  instagram,
  telegram,
}

@RoutePage(name: 'FollowUs')
class FollowUs extends StatelessWidget {
  FollowUs({super.key});

  final countryMap = {
    //Russia
    'ru': {
      _Social.facebook:
          'https://www.facebook.com/profile.php?id=61555417626781',
      _Social.x: 'https://twitter.com/Lantern_Russia',
      _Social.instagram: 'https://www.instagram.com/lantern.io_ru',
      _Social.telegram: 'https://t.me/lantern_russia',
    },
    //iran
    'ir': {
      _Social.facebook: 'https://www.facebook.com/getlanternpersian',
      _Social.x: 'https://twitter.com/getlantern_fa',
      _Social.instagram: 'https://www.instagram.com/getlantern_fa/',
      _Social.telegram: 'https://t.me/LanternFarsi',
    },
    //Ukraine
    'ua': {
      _Social.facebook:
          'https://www.facebook.com/profile.php?id=61554740875416',
      _Social.x: 'https://twitter.com/LanternUA',
      _Social.instagram: 'https://www.instagram.com/getlantern_ua/',
      _Social.telegram: 'https://t.me/lanternukraine',
    },
    //Belarus
    'by': {
      _Social.facebook:
          'https://www.facebook.com/profile.php?id=61554406268221',
      _Social.x: 'https://twitter.com/LanternBelarus',
      _Social.instagram: 'https://www.instagram.com/getlantern_belarus/',
      _Social.telegram: 'https://t.me/lantern_belarus',
    },
    //United Arab Emirates
    'uae': {
      _Social.facebook:
          'https://www.facebook.com/profile.php?id=61554655199439',
      _Social.x: 'https://twitter.com/getlantern_UAE',
      _Social.instagram: 'https://www.instagram.com/lanternio_uae/',
      _Social.telegram: 'https://t.me/lantern_uae',
    },
    //Guinea
    'gn': {
      _Social.facebook:
          'https://www.facebook.com/profile.php?id=61554620251833',
      _Social.x: 'https://twitter.com/getlantern_gu',
      _Social.instagram: 'https://www.instagram.com/lanternio_guinea/',
      _Social.telegram: 'https://t.me/LanternGuinea',
    },
    'all': {
      _Social.facebook: 'https://www.facebook.com/getlantern',
      _Social.x: 'https://twitter.com/getlantern',
      _Social.instagram: 'https://www.instagram.com/getlantern/',
      _Social.telegram: '',
    },
  };

  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'follow_us'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    return Card(
      child: FollowUsListView(),
    );
  }
}

class FollowUsListView extends StatelessWidget {
  const FollowUsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        AppTile(
          label: 'telegram'.i18n,
          icon: AppImagePaths.telegram,
          trailing: AppImage(path: AppImagePaths.outsideBrowser),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
        AppTile(
          label: 'instagram'.i18n,
          icon: AppImagePaths.instagram,
          trailing: AppImage(path: AppImagePaths.outsideBrowser),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
        AppTile(
          label: 'x'.i18n,
          icon: AppImagePaths.x,
          trailing: AppImage(path: AppImagePaths.outsideBrowser),
        ),
      ],
    );
  }
}

void showFollowUsBottomSheet({required BuildContext context}) {
  showAppBottomSheet(
    context: context,
    title: 'follow_us'.i18n,
    scrollControlDisabledMaxHeightRatio: 0.37,
    builder: (context, scrollController) {
      return FollowUsListView();
    },
  );
}
