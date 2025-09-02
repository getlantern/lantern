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
      if (flags.isGCPEnabled)
        (
          provider: CloudProvider.googleCloud,
          cta: 'continue_with_${CloudProvider.googleCloud.value}'.i18n,
          card: ProviderCard(
            title: 'server_setup_gcp'.i18n,
            price: 'server_setup_gcp_price'.i18n.fill(['\$8']),
            provider: CloudProvider.googleCloud,
            icon: AppImagePaths.googleCloud,
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
          title: 'server_setup_do'.i18n,
          price: 'server_setup_do_price'.i18n.fill(['\$8']),
          provider: CloudProvider.digitalOcean,
          icon: AppImagePaths.digitalOceanIcon,
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
              builder: (_) => const DigitalOceanLocations(),
            );
          },
        ),
      ),
    ];

    Future<void> _continue() async {
      final selected = cards[selectedIdx.value].provider;
      final Either<Failure, Unit> result;
      if (selected == CloudProvider.googleCloud) {
        result = await ref
            .read(privateServerNotifierProvider.notifier)
            .googleCloud();
      } else {
        result = await ref
            .read(privateServerNotifierProvider.notifier)
            .digitalOcean();
      }
      result.fold(
        (f) => context.showSnackBar(f.localizedErrorMessage),
        (_) {},
      );
    }

    final continueButton = SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF012D2D),
          foregroundColor: AppColors.gray1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        ),
        onPressed: _continue,
        child: Text(
          cards[selectedIdx.value].cta,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.gray1,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
        ),
      ),
    );

    // Manual button (after continue)
    final manualButton = SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.gray5, width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          foregroundColor: AppColors.black1,
        ),
        onPressed: () => appRouter.push(ManuallyServerSetup()),
        child: Text(
          'Set Up Manually',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.black1,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
        ),
      ),
    );

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
                  continueButton,
                  const SizedBox(height: 8),
                  manualButton,
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
