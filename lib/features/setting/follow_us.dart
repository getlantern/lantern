import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';

enum _Social { x, instagram, telegram }

@RoutePage(name: 'FollowUs')
class FollowUs extends StatelessWidget {
  const FollowUs({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppBuildInfo.enableSocialLinks) {
      return BaseScreen(title: 'follow_us'.i18n, body: const SizedBox.shrink());
    }
    return BaseScreen(title: 'follow_us'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    return Card(child: FollowUsListView());
  }
}

class FollowUsListView extends ConsumerWidget {
  final ScrollController? scrollController;

  const FollowUsListView({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(countryCodeProvider).toUpperCase();
    final selectedCountry = CountryCode.censoredRegions.contains(country)
        ? country
        : 'ALL';

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
        if (countryMap[selectedCountry]![_Social.telegram]!.isNotEmpty &&
            CountryCode.censoredRegions.contains(selectedCountry))
          AppTile.link(
            label: 'telegram'.i18n,
            icon: AppImagePaths.telegram,
            url: countryMap[selectedCountry]![_Social.telegram]!,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
        if (countryMap[selectedCountry]![_Social.instagram]!.isNotEmpty &&
            selectedCountry != 'CN')
          AppTile.link(
            label: 'instagram'.i18n,
            icon: AppImagePaths.instagram,
            url: countryMap[selectedCountry]![_Social.instagram]!,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DividerSpace(),
        ),
        if (countryMap[selectedCountry]![_Social.x]!.isNotEmpty)
          AppTile.link(
            label: 'x'.i18n,
            icon: AppImagePaths.x,
            url: countryMap[selectedCountry]![_Social.x]!,
          ),
      ],
    );
  }
}
