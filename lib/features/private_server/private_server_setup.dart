import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
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
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                  title: 'server_setup_gcp'.i18n,
                  price: 'server_setup_gcp_price'.i18n.fill(['\$8']),
                  provider: CloudProvider.googleCloud,
                  onContinue: () => appRouter.push(PrivateServerGCP()),
                  icon: AppImagePaths.googleCloud,
                ),
                ProviderCard(
                  title: 'server_setup_do'.i18n,
                  price: 'server_setup_do_price'.i18n.fill(['\$8']),
                  provider: CloudProvider.digitalOcean,
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
      ),
    );
  }
}
