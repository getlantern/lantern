import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';
import 'package:lantern/features/private_server/provider_card.dart';
import 'package:lantern/features/private_server/provider_carousel.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

@RoutePage(name: 'PrivateServerSetup')
class PrivateServerSetup extends StatefulHookConsumerWidget {
  const PrivateServerSetup({super.key});

  @override
  ConsumerState<PrivateServerSetup> createState() => _PrivateServerSetupState();
}

class _PrivateServerSetupState extends ConsumerState<PrivateServerSetup> {
  final CloudProvider _selectedProvider = CloudProvider.digitalOcean;

  /// Handle a non-openBrowser server state update.
  /// Returns true if the status was recognized and acted on.
  bool _handleServerState(PrivateServerStatus serverState) {
    if (!context.mounted) {
      appLogger.warning(
        "Received private server state update while context not mounted: ${serverState.status}",
      );
      return true;
    }

    switch (serverState.status) {
      case 'EventTypeOAuthError':
        context.hideLoadingDialog();
        context.showSnackBar('private_server_setup_error'.i18n);
        return true;
      case 'EventTypeOAuthCancelled':
        context.hideLoadingDialog();
        return true;
      case 'EventTypeNoProjects':
      case 'error':
        context.hideLoadingDialog();
        context.showSnackBar(
          serverState.error ?? 'private_server_setup_error'.i18n,
        );
        return true;
      case 'EventTypeOnlyCompartment':
        context.hideLoadingDialog();
        appRouter.push(
          PrivateServerDetails(
            accounts: [],
            provider: _selectedProvider,
            isPreFilled: true,
          ),
        );
        return true;
      case 'EventTypeAccounts':
        context.hideLoadingDialog();
        final accounts = serverState.data!.split(', ');
        appRouter.push(
          PrivateServerDetails(accounts: accounts, provider: _selectedProvider),
        );
        return true;
      case 'EventTypeValidationError':
        if (serverState.error?.contains('account is not active') ?? false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.hideLoadingDialog();
            ref.read(privateServerProvider.notifier).resetPrivateServerState();
            appRouter.push(PrivateServerAddBilling());
          });
          return true;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.hideLoadingDialog();
          ref.read(privateServerProvider.notifier).resetPrivateServerState();
          appLogger.error(
            "Private server deployment failed.",
            serverState.error,
          );
          AppDialog.errorDialog(
            context: context,
            title: 'error'.i18n,
            content: serverState.error!,
          );
        });
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(privateServerProvider);
    appLogger.info("Current private server state: ${serverState.status}");
    final isGCPEnabled = false;
    final selectedIdx = useState(0);
    useEffect(() {
      if (serverState.status == 'openBrowser') {
        UrlUtils.openWebview<bool>(
          serverState.data!,
          onWebviewResult: (ok) {
            if (ok) {
              context.showLoadingDialog();
              // Events from Go may have arrived while the webview was open.
              // Re-check the current notifier state so they aren't missed.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                final current = ref.read(privateServerProvider);
                _handleServerState(current);
              });
            }
          },
        );
      } else {
        _handleServerState(serverState);
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
                useThemeColor: false,
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
    CloudProvider provider,
    WidgetRef ref,
    BuildContext context,
  ) async {
    // The cloud provider OAuth webview may fail to load when VPN is
    // active (the tunnel can block outbound traffic to the provider).
    // Disconnect first so the webview can reach the OAuth endpoint.
    final vpnStatus = ref.read(vpnProvider);
    if (vpnStatus == VPNStatus.connected || vpnStatus == VPNStatus.connecting) {
      await ref.read(vpnProvider.notifier).stopVPN();
    }

    final Either<Failure, Unit> result;
    if (provider == CloudProvider.googleCloud) {
      result = await ref.read(privateServerProvider.notifier).googleCloud();
    } else {
      result = await ref.read(privateServerProvider.notifier).digitalOcean();
    }
    result.fold((f) => context.showSnackBar(f.localizedErrorMessage), (_) {});
  }
}
