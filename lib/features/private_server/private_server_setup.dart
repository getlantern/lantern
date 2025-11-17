import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart';
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
  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(privateServerProvider);
    final isGCPEnabled = false;

    final selectedIdx = useState(0);
    final CloudProvider selectedProvider = CloudProvider.digitalOcean;
    final route = ModalRoute.of(context);
    useEffect(() {
      if (route == null || !route.isCurrent) return null;

      if (serverState.status == 'openBrowser') {
        UrlUtils.openWebview<bool>(
          serverState.data!,
          onWebviewResult: (ok) {
            if (ok) context.showLoadingDialog();
          },
        );
      }
      if (serverState.status == 'EventTypeOAuthError') {
        context.showSnackBar('private_server_setup_error'.i18n);
      }
      if (serverState.status == 'EventTypeOnlyCompartment') {
        context.hideLoadingDialog();
        appRouter.push(PrivateServerDetails(
            accounts: [], provider: selectedProvider, isPreFilled: true));
      }
      if (serverState.status == 'EventTypeAccounts') {
        context.hideLoadingDialog();
        final accounts = serverState.data!.split(', ');
        appRouter.push(PrivateServerDetails(
            accounts: accounts, provider: selectedProvider));
      }
      if (serverState.status == 'EventTypeValidationError') {
        if (!context.mounted) {
          return;
        }

        /// User has created new account but it does not have billing set up yet
        if (serverState.error?.contains('account is not active') ?? false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.hideLoadingDialog();
            appRouter.push(PrivateServerAddBilling());
          });
          return;
        }
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
      if (isGCPEnabled)
        (
          provider: CloudProvider.googleCloud,
          cta: 'continue_with_${CloudProvider.googleCloud.value}'.i18n,
          card: ProviderCard(
            features: [
              'we_handle_configuration'.i18n,
              'server_setup_gcp_price'.i18n.fill(['\$8']),
              'choose_your_server_location'.i18n,
              '90_day_free_trial'.i18n,
              'one_month_included'.i18n.fill([1]),
            ],
            buttonTitle:
                'continue_with_${CloudProvider.googleCloud.value}'.i18n,
            title: 'server_setup_gcp'.i18n,
            provider: CloudProvider.googleCloud,
            icon: AppImagePaths.googleCloud,
            onContinueClicked: () =>
                _continue(CloudProvider.googleCloud, ref, context),
          ),
        ),
      (
        provider: CloudProvider.digitalOcean,
        cta: 'continue_with_${CloudProvider.digitalOcean.value}'.i18n,
        card: ProviderCard(
          features: [
            'easiest_setup_process'.i18n,
            'server_setup_do_price'.i18n.fill(['\$8']),
            'seamless_integration'.i18n,
            'choose_your_server_location'.i18n,
            'one_month_included'.i18n.fill([1]),
          ],
          buttonTitle: 'continue_with_${CloudProvider.digitalOcean.value}'.i18n,
          title: 'server_setup_do'.i18n,
          provider: CloudProvider.digitalOcean,
          icon: AppImagePaths.digitalOceanIcon,
          onContinueClicked: () =>
              _continue(CloudProvider.digitalOcean, ref, context),
        ),
      ),
    ];

    return BaseScreen(
      title: 'setup_a_private_server'.i18n,
      padded: false,
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: defaultSize),
              AppImage(
                path: AppImagePaths.serverRack,
                type: AssetType.svg,
                height: PlatformUtils.isDesktop ? 190.h : 160.h,
              ),
              const SizedBox(height: defaultSize),
              ProviderCarousel(
                cards: cards.map((e) => e.card).toList(),
                onPageChanged: (i) => selectedIdx.value = i,
              ),
              const SizedBox(height: size24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SecondaryButton(
                  label: 'server_setup_manual'.i18n,
                  isTaller: true,
                  onPressed: () {
                    appRouter.push(ManuallyServerSetup());
                  },
                ),
              ),
              const SizedBox(height: kBottomNavigationBarHeight),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continue(
      CloudProvider provider, WidgetRef ref, BuildContext context) async {
    final Either<Failure, Unit> result;
    if (provider == CloudProvider.googleCloud) {
      result = await ref.read(privateServerProvider.notifier).googleCloud();
    } else {
      result = await ref.read(privateServerProvider.notifier).digitalOcean();
    }
    result.fold(
      (f) => context.showSnackBar(f.localizedErrorMessage),
      (_) {},
    );
  }
}
