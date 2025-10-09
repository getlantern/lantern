import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/screen_utils.dart';

import '../../core/utils/ip_utils.dart' show IPUtils;

enum _Social {
  x,
  instagram,
  telegram,
}

@RoutePage(name: 'FollowUs')
class FollowUs extends StatelessWidget {
  FollowUs({super.key});

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

class FollowUsListView extends HookWidget {
  final ScrollController? scrollController;

  const FollowUsListView({
    super.key,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCountry = useState<String>('ALL');
    useEffect(() {
      IPUtils.getUserCountry().then((country) {
        appLogger.debug('User country: $country');
        if (IPUtils.censoredRegion.contains(country)) {
          selectedCountry.value = country ?? 'ALL';
        } else {
          selectedCountry.value = 'ALL';
        }
      });
      return null;
    }, []);

    final countryMap = {
      //Russia
      'RU': {
        _Social.x: 'https://twitter.com/Lantern_Russia',
        _Social.instagram: 'https://www.instagram.com/lantern.io_ru',
        _Social.telegram: 'https://t.me/lantern_russia',
      },
      //iran
      'IR': {
        _Social.x: 'https://twitter.com/getlantern_fa',
        _Social.instagram: 'https://www.instagram.com/getlantern_fa/',
        _Social.telegram: 'https://t.me/LanternFarsi',
      },
      'CN': {
        _Social.x: 'https://twitter.com/getlantern_CN',
        _Social.instagram: '',
        _Social.telegram: 'https://t.me/lantern_china',
      },

      'ALL': {
        _Social.x: 'https://twitter.com/getlantern',
        _Social.instagram: 'https://www.instagram.com/getlantern/',
        _Social.telegram: '',
      },
    };

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        if (countryMap[selectedCountry.value]![_Social.telegram]!.isNotEmpty &&
            IPUtils.censoredRegion.contains(selectedCountry.value))
          AppTile.link(
            label: 'telegram'.i18n,
            icon: AppImagePaths.telegram,
            url: countryMap[selectedCountry.value]![_Social.telegram]!,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
        if (countryMap[selectedCountry.value]![_Social.instagram]!.isNotEmpty &&
            selectedCountry.value != 'CN')
          AppTile.link(
            label: 'instagram'.i18n,
            icon: AppImagePaths.instagram,
            url: countryMap[selectedCountry.value]![_Social.instagram]!,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
        if (countryMap[selectedCountry.value]![_Social.x]!.isNotEmpty)
          AppTile.link(
            label: 'x'.i18n,
            icon: AppImagePaths.x,
            url: countryMap[selectedCountry.value]![_Social.x]!,
          ),
      ],
    );
  }
}

void showFollowUsBottomSheet({required BuildContext context}) {
  showAppBottomSheet(
    context: context,
    title: 'follow_us'.i18n,
    scrollControlDisabledMaxHeightRatio: context.isSmallDevice ? 0.39.h : 0.3.h,
    builder: (context, scrollController) {
      return Flexible(
        child: FollowUsListView(
          scrollController: scrollController,
        ),
      );
    },
  );
}
