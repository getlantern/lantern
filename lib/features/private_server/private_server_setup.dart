import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/server_locations.dart';
import 'package:lantern/features/private_server/provider_card.dart';
import 'package:lantern/features/private_server/provider_carousel.dart';

@RoutePage(name: 'PrivateServerSetup')
class PrivateServerSetup extends StatelessWidget {
  const PrivateServerSetup({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'setup_private_server'.i18n,
      padded: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Center(
            child: AppImage(
              path: AppImagePaths.serverRack,
              type: AssetType.svg,
              height: 180.h,
              width: 180.w,
            ),
          ),
          SizedBox(height: 16),
          ProviderCarousel(
            cards: [
              ProviderCard(
                provider: 'gcp',
                title: 'server_setup_do'.i18n,
                price: 'server_setup_do_price'.i18n.fill(['\$8']),
                onContinue: () {},
                icon: AppImagePaths.digitalOceanIcon,
              ),
              ProviderCard(
                provider: 'do',
                title: 'server_setup_do'.i18n,
                price: 'server_setup_do_price'.i18n.fill(['\$9']),
                onContinue: () {},
                icon: AppImagePaths.digitalOceanIcon,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'server_setup_manual'.i18n,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
