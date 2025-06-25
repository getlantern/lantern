import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
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
  bool browserOpened = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(privateServerNotifierProvider);
    useEffect(() {
      if (serverState.status == 'openBrowser') {
        //Since build method is called multiple times, we need to check if the browser is already opened
        if (!browserOpened) {
          browserOpened = true;
          UrlUtils.openWebview<bool>(
            serverState.data!,
            onWebviewResult: (p0) {
              if (p0) {
                context.showLoadingDialog();
              }
              browserOpened = false;
            },
          );
        }
      }
      if (serverState.status == 'EventTypeOAuthError') {
        context.showSnackBar('private_server_setup_error'.i18n);
      }
      if (serverState.status == 'EventTypeAccounts') {
        //Got account from cloud provider
        context.hideLoadingDialog();
        final accounts = serverState.data!;
        appRouter.push(PrivateServerDetails(accounts: [accounts]));
      }

      if (serverState.status == 'EventTypeValidationError') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.hideLoadingDialog();
          appLogger.error(
              "Private server deployment failed.", serverState.error);
          AppDialog.errorDialog(
              context: context,
              title: 'error'.i18n,
              content: serverState.error!);
        });
      }

      return null;
    }, [serverState.status]);

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
                onContinue: onDigitalOceanTap,
                icon: AppImagePaths.googleCloud,
                title: 'server_setup_gcp'.i18n,
                price: 'server_setup_do_price'.i18n.fill(['\$3']),
              ),
              ProviderCard(
                title: 'server_setup_do'.i18n,
                price: 'server_setup_do_price'.i18n.fill(['\$8']),
                provider: CloudProvider.digitalOcean,
                onContinue: onDigitalOceanTap,
                icon: AppImagePaths.digitalOceanIcon,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'server_setup_manual'.i18n,
            onPressed: () {
              appRouter.push(const ManuallyServerSetup());
            },
          ),
        ],
      ),
    );
  }

  Future<void> onDigitalOceanTap() async {
    final result =
        await ref.read(privateServerNotifierProvider.notifier).digitalOcean();
    result.fold(
      (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {},
    );
  }
}
