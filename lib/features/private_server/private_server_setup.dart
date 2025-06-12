import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/server_locations.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';
import 'package:lantern/features/private_server/provider_card.dart';
import 'package:lantern/features/private_server/provider_carousel.dart';

@RoutePage(name: 'PrivateServerSetup')
class PrivateServerSetup extends StatefulHookConsumerWidget {
  const PrivateServerSetup({super.key});

  @override
  ConsumerState<PrivateServerSetup> createState() => _PrivateServerSetupState();
}

class _PrivateServerSetupState extends ConsumerState<PrivateServerSetup> {
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
                provider: CloudProvider.googleCloud,
                onContinue: () {},
                icon: AppImagePaths.googleCloud,
                title: 'server_setup_do'.i18n,
                price: 'server_setup_do_price'.i18n.fill(['\$8']),
                onContinue: onDigitalOceanTap,
                icon: AppImagePaths.digitalOceanIcon,
              ),
              ProviderCard(
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
    );
  }

  Future<void> onDigitalOceanTap() async {
    //Start the Digital Ocean setup process
    final result =
        await ref.read(privateServerNotifierProvider.notifier).digitalOcean();

    result.fold(
      (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (success) {
        //Listen to the private server status before so we don't miss any evens
        ref
            .read(privateServerNotifierProvider.notifier)
            .watchPrivateServerLogs()
            .listen(listenForStatusChange);
      },
    );
  }

  void listenForStatusChange(PrivateServerStatus status) {
    appLogger.info("Private server status changed: ${status.status}");
    switch (status.status) {
      case 'openBrowser':
        // Open the browser to the private server URL
        final url = status.data ?? '';
        if (url.isEmpty) {
          context.showSnackBar('private_server_setup_error'.i18n);
          return;
        }
        // Open the URL in a webview
        UrlUtils.openWebview(url);
        break;
      case 'error':
        // Show an error message
        context.showSnackBar('private_server_setup_error'.i18n);
        break;
    }
  }
}
