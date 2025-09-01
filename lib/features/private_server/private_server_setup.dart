import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';
import 'package:lantern/features/private_server/provider_card.dart';
import 'package:lantern/features/private_server/provider_carousel.dart';
import 'package:lantern/features/private_server/server_locations_modal.dart';

@RoutePage(name: 'PrivateServerSetup')
class PrivateServerSetup extends HookConsumerWidget {
  const PrivateServerSetup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(privateServerNotifierProvider);
    final flags = ref.read(featureFlagNotifierProvider.notifier);

    final browserOpened = useRef(false);
    final selectedIdx = useState(0);

    useEffect(() {
      if (serverState.status == 'openBrowser' && !browserOpened.value) {
        browserOpened.value = true;
        UrlUtils.openWebview<bool>(
          serverState.data!,
          onWebviewResult: (ok) {
            if (ok) context.showLoadingDialog();
            browserOpened.value = false;
          },
        );
      }
      if (serverState.status == 'EventTypeOAuthError') {
        context.showSnackBar('private_server_setup_error'.i18n);
      }
      if (serverState.status == 'EventTypeAccounts') {
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
            content: serverState.error!,
          );
        });
      }
      return null;
    }, [serverState.status]);

    // Cards
    final cards = <({CloudProvider provider, Widget card, String cta})>[
      if (flags.isGCPFlag())
        (
          provider: CloudProvider.googleCloud,
          cta: 'continue_with_${CloudProvider.googleCloud.value}'.i18n,
          card: ProviderCard(
            buttonTitle:
                'continue_with_${CloudProvider.googleCloud.value}'.i18n,
            title: 'server_setup_gcp'.i18n,
            price: 'server_setup_gcp_price'.i18n.fill(['\$8']),
            provider: CloudProvider.googleCloud,
            icon: AppImagePaths.googleCloud,
            onContinueClicked: () => _continue(
                CloudProvider.googleCloud, ref, context),
            onShowLocations: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Theme.of(context).canvasColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                builder: (_) => const GoogleCloudLocations(),
              );
            },
          ),
        ),
      (
        provider: CloudProvider.digitalOcean,
        cta: 'continue_with_${CloudProvider.digitalOcean.value}'.i18n,
        card: ProviderCard(
          buttonTitle: 'continue_with_${CloudProvider.digitalOcean.value}'.i18n,
          title: 'server_setup_do'.i18n,
          price: 'server_setup_do_price'.i18n.fill(['\$8']),
          provider: CloudProvider.digitalOcean,
          icon: AppImagePaths.digitalOceanIcon,
          onShowLocations: () {},
          onContinueClicked: () => _continue(
              CloudProvider.digitalOcean, ref, context),
        ),
      ),
    ];

    return BaseScreen(
      title: 'setup_private_server'.i18n,
      padded: false,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Center(
                      child: AppImage(
                        path: AppImagePaths.serverRack,
                        type: AssetType.svg,
                        width: 140,
                        height: 140,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProviderCarousel(
                    cards: cards.map((e) => e.card).toList(),
                    onPageChanged: (i) => selectedIdx.value = i,
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'server_setup_manual'.i18n,
                    isTaller: true,
                    onPressed: () {
                      appRouter.push(ManuallyServerSetup());
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continue(
      CloudProvider provider, WidgetRef ref, BuildContext context) async {
    final Either<Failure, Unit> result;
    if (provider == CloudProvider.googleCloud) {
      result =
          await ref.read(privateServerNotifierProvider.notifier).googleCloud();
    } else {
      result =
          await ref.read(privateServerNotifierProvider.notifier).digitalOcean();
    }
    result.fold(
      (f) => context.showSnackBar(f.localizedErrorMessage),
      (_) {},
    );
  }
}
