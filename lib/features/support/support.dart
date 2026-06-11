import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/utils/route_utils.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/features/setting/follow_us.dart' hide FollowUs;
import 'package:lantern/features/support/app_version.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';

@RoutePage(name: 'Support')
class Support extends ConsumerWidget {
  const Support({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScreen(
      title: toBeginningOfSentenceCase('support'.i18n),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Center(
              child: AppImage(
                path: AppImagePaths.supportIllustration,
                useThemeColor: false,
                type: AssetType.svg,
                height: 180.h,
                width: 180.w,
              ),
            ),
            gap16,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    icon: Icons.error_outline,
                    label: 'report_an_issue'.i18n,
                    onPressed: () => safePush(context, ReportIssue()),
                  ),
                  const DividerSpace(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  AppTile(
                    icon: Icons.code_outlined,
                    label: 'diagnostic_logs'.i18n,
                    onPressed: () => safePush(context, Logs()),
                  ),
                  const DividerSpace(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  AppTile(
                    icon: Icons.refresh,
                    label: 'refresh_configuration'.i18n,
                    onPressed: () => onRefreshConfiguration(context, ref),
                  ),
                ],
              ),
            ),
            gap16,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile.link(
                    icon: Icons.forum_outlined,
                    label: 'lantern_user_forum'.i18n,
                    url: AppUrls.lanternForums,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                  const DividerSpace(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  AppTile.link(
                    icon: Icons.info_outlined,
                    label: 'frequently_asked_questions'.i18n,
                    url: AppUrls.faq,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                  const DividerSpace(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  AppTile.link(
                    icon: Icons.privacy_tip_outlined,
                    label: 'privacy_policy'.i18n,
                    url: AppUrls.privacyPolicy,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                  const DividerSpace(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  AppTile.link(
                    icon: Icons.description_outlined,
                    label: 'terms_of_service'.i18n,
                    url: AppUrls.termsOfService,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: defaultSize),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  DividerSpace(),
                  AppTile(
                    label: 'download_links'.i18n,
                    icon: AppImagePaths.desktop,
                    onPressed: () {
                      appRouter.push(DownloadLinks());
                    },
                  ),
                  DividerSpace(),
                  AppTile(
                    label: 'follow_us'.i18n,
                    icon: AppImagePaths.thumb,
                    onPressed: () {
                      if (PlatformUtils.isDesktop) {
                        appRouter.push(FollowUs());
                        return;
                      }
                      showFollowUsBottomSheet(context: context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: defaultSize),
            const AppVersion(),
            const SizedBox(height: size24),
          ],
        ),
      ),
    );
  }

  void showFollowUsBottomSheet({required BuildContext context}) {
    showAppBottomSheet(
      context: context,
      title: 'follow_us'.i18n,
      scrollControlDisabledMaxHeightRatio: context.isSmallDevice
          ? 0.39.h
          : 0.3.h,
      builder: (context, scrollController) {
        return Flexible(
          child: FollowUsListView(scrollController: scrollController),
        );
      },
    );
  }

  Future<void> onRefreshConfiguration(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Clearing the tunnel cache requires the tunnel to be fully stopped, so
    // only proceed when the VPN is disconnected. Any other state (connected,
    // connecting, disconnecting, missingPermission, error) is treated as an
    // active/in-transition tunnel and is blocked.
    appLogger.info('Attempting to refresh configuration');
    final vpnStatus = ref.read(vpnProvider);
    if (vpnStatus != VPNStatus.disconnected) {
      appLogger.warning(
        'VPN is not disconnected (current status: $vpnStatus). Aborting configuration refresh.',
      );
      AppDialog.dialog(
        context: context,
        title: 'turn_off_vpn'.i18n,
        content: 'turn_off_vpn_message'.i18n,
        action: 'got_it'.i18n,
      );
      return;
    }

    appLogger.info(
      'VPN is disconnected. Proceeding with configuration refresh.',
    );
    final result = await sl<LanternService>().clearTunnelCache();
    if (!context.mounted) return;
    result.match(
      (failure) {
        context.showSnackBarError('it_looks_like_something_went_wrong'.i18n);
        appLogger.error('Failed to refresh configuration: $failure');
      },

      (_) {
        appLogger.info('Configuration refresh successful. Notifying user.');
        final textTheme = TextTheme.of(context);

        AppDialog.customDialog(
          context: context,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: defaultSize),
              AppImage(
                path: AppImagePaths.greenCheck,
                width: 48,
                useThemeColor: false,
              ),
              SizedBox(height: defaultSize),
              Text(
                'configuration_cleared'.i18n,
                style: textTheme.headlineMedium,
              ),
              SizedBox(height: defaultSize),
              Text('configuration_message'.i18n, style: textTheme.bodyMedium),
            ],
          ),
          action: [
            AppTextButton(
              label: 'close'.i18n,
              textColor: context.textSecondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppTextButton(
              label: 'turn_on_vpn'.i18n,
              onPressed: () => startVPNAfterRefresh(context, ref),
            ),
          ],
        );
      },
    );
  }

  Future<void> startVPNAfterRefresh(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    final result = await ref.read(vpnProvider.notifier).startVPN();
    if (!context.mounted) return;
    result.fold((failure) {
      if (failure is VpnConflictFailure) {
        AppDialog.vpnConflictDialog(
          context: context,
          onConnectAnyway: () async {
            appRouter.maybePop();
            final retryResult = await ref
                .read(vpnProvider.notifier)
                .startVPN(skipConflictCheck: true);
            if (!context.mounted) return;
            retryResult.fold((failure) {
              context.showSnackBar(failure.localizedErrorMessage);
              appLogger.error(
                'Error starting VPN after configuration refresh: ${failure.error}',
              );
            }, (_) => appRouter.popUntilRoot());
          },
        );
        return;
      }
      context.showSnackBar(failure.localizedErrorMessage);
      appLogger.error(
        'Error starting VPN after configuration refresh: ${failure.error}',
      );
    }, (_) => appRouter.popUntilRoot());
  }
}
