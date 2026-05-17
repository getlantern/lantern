import 'package:auto_route/annotations.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/common/stealth_no_vpn_proxy.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';

@RoutePage(name: 'VPNSetting')
class VPNSetting extends HookConsumerWidget {
  const VPNSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScreen(
      title: (AppBuildInfo.stealthNoVpn ? 'proxy_setup' : 'vpn_settings').i18n,
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    if (AppBuildInfo.stealthNoVpn) {
      return _buildNoVpnBody(context, ref);
    }
    final textTheme = Theme.of(context).textTheme;
    final isUserPro = ref.watch(isUserProProvider);
    final isPrivateServerFound = ref.watch(isPrivateServerFoundProvider);
    final splitTunnelingEnabled = ref.watch(
      radianceSettingsProvider.select((s) => s.splitTunneling),
    );
    final routingMode = ref.watch(
      radianceSettingsProvider.select((s) => s.routingMode),
    );
    final blockAds = ref.watch(
      radianceSettingsProvider.select((s) => s.blockAds),
    );
    final telemetryConsent = ref.watch(
      radianceSettingsProvider.select((s) => s.telemetry),
    );

    return ListView(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      children: <Widget>[
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTile(
                label: 'server_locations'.i18n,
                icon: AppImagePaths.location,
                trailing: AppImage(
                  path: AppImagePaths.arrowForward,
                  height: 20,
                ),
                onPressed: () {
                  appRouter.push(const ServerSelection());
                },
              ),
              if (!PlatformUtils.isIOS) ...{
                DividerSpace(),
                SplitTunnelingTile(
                  label: 'routing_mode'.i18n,
                  icon: AppImagePaths.route,
                  actionText: routingMode.label(),
                  onPressed: () => appRouter.push(const SmartRouting()),
                ),
              },
              DividerSpace(),
              if (PlatformUtils.isAndroid ||
                  PlatformUtils.isMacOS ||
                  PlatformUtils.isWindows) ...{
                SplitTunnelingTile(
                  label: 'split_tunneling'.i18n,
                  icon: AppImagePaths.callSpilt,
                  actionText: splitTunnelingEnabled
                      ? 'enabled'.i18n
                      : 'disabled'.i18n,
                  onPressed: () => appRouter.push(const SplitTunneling()),
                ),
                DividerSpace(),
              },
            ],
          ),
        ),
        SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            label: 'block_ads'.i18n,
            subtitle: Text(
              'only_active'.i18n,
              style: textTheme.labelMedium!.copyWith(
                color: context.textTertiary,
                letterSpacing: 0.0,
              ),
            ),
            icon: AppImagePaths.blockAds,
            trailing: SwitchButton(
              value: blockAds,
              onChanged: (bool? value) {
                if (!isUserPro) {
                  appRouter.push(Plans());
                  return;
                }
                ref
                    .read(radianceSettingsProvider.notifier)
                    .setBlockAds(value ?? false);
              },
            ),
            onPressed: () {
              if (!isUserPro) {
                appRouter.push(Plans());
                return;
              }
              ref
                  .read(radianceSettingsProvider.notifier)
                  .setBlockAds(!blockAds);
            },
          ),
        ),
        SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTile(
                label: 'setup_private_server'.i18n,
                icon: AppImagePaths.server,
                trailing: AppImage(
                  path: AppImagePaths.arrowForward,
                  height: 20,
                ),
                onPressed: () => appRouter.push(const PrivateServerSetup()),
              ),
              DividerSpace(),
              AppTile(
                label: 'join_private_server'.i18n,
                icon: AppImagePaths.joinServer,
                trailing: AppImage(
                  path: AppImagePaths.arrowForward,
                  height: 20,
                ),
                onPressed: () => appRouter.push(JoinPrivateServer()),
              ),
              DividerSpace(),
              if (isPrivateServerFound)
                AppTile(
                  label: 'manage_private_servers'.i18n,
                  icon: AppImagePaths.settingServer,
                  trailing: AppImage(
                    path: AppImagePaths.arrowForward,
                    height: 20,
                  ),
                  onPressed: () => appRouter.push(const ManagePrivateServer()),
                ),
            ],
          ),
        ),
        DividerSpace(),
        SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            minHeight: PlatformUtils.isWindows ? 82.0 : 72.0,
            label: 'anonymous_usage_data'.i18n,
            icon: AppImagePaths.assessment,
            subtitle: AutoSizeText(
              'helps_improve_lantern_performance'.i18n,
              minFontSize: 12,
              maxFontSize: 12,
              maxLines: 2,
              style: textTheme.labelMedium!.copyWith(
                color: context.textTertiary,
                letterSpacing: 0.0,
              ),
            ),
            trailing: SwitchButton(
              value: telemetryConsent,
              onChanged: (value) {
                appLogger.info('Anonymous usage data consent changed: $value');
                ref.read(radianceSettingsProvider.notifier).setTelemetry(value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoVpnBody(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isUserPro = ref.watch(isUserProProvider);
    final blockAds = ref.watch(
      radianceSettingsProvider.select((s) => s.blockAds),
    );
    final telemetryConsent = ref.watch(
      radianceSettingsProvider.select((s) => s.telemetry),
    );
    return ListView(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            label: 'server_locations'.i18n,
            icon: AppImagePaths.location,
            trailing: AppImage(path: AppImagePaths.arrowForward, height: 20),
            onPressed: () {
              appRouter.push(const ServerSelection());
            },
          ),
        ),
        SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('manual_proxy_setup'.i18n, style: textTheme.titleMedium),
              SizedBox(height: 8),
              Text(
                'manual_proxy_setup_description'.i18n,
                style: textTheme.bodyMedium!.copyWith(
                  color: context.textSecondary,
                ),
              ),
              SizedBox(height: 16),
              _ProxySetting(
                label: 'proxy_host'.i18n,
                value: StealthNoVpnProxy.host,
              ),
              DividerSpace(),
              _ProxySetting(
                label: 'proxy_port'.i18n,
                value: StealthNoVpnProxy.port.toString(),
              ),
              DividerSpace(),
              _ProxySetting(
                label: 'socks5_proxy'.i18n,
                value: StealthNoVpnProxy.address,
              ),
              DividerSpace(),
              _ProxySetting(
                label: 'http_connect_proxy'.i18n,
                value: StealthNoVpnProxy.address,
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            label: 'block_ads'.i18n,
            icon: AppImagePaths.blockAds,
            trailing: SwitchButton(
              value: blockAds,
              onChanged: (bool? value) {
                if (!isUserPro) {
                  appRouter.push(Plans());
                  return;
                }
                ref
                    .read(radianceSettingsProvider.notifier)
                    .setBlockAds(value ?? false);
              },
            ),
            onPressed: () {
              if (!isUserPro) {
                appRouter.push(Plans());
                return;
              }
              ref
                  .read(radianceSettingsProvider.notifier)
                  .setBlockAds(!blockAds);
            },
          ),
        ),
        SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            minHeight: PlatformUtils.isWindows ? 82.0 : 72.0,
            label: 'anonymous_usage_data'.i18n,
            icon: AppImagePaths.assessment,
            subtitle: AutoSizeText(
              'helps_improve_lantern_performance'.i18n,
              minFontSize: 12,
              maxFontSize: 12,
              maxLines: 2,
              style: textTheme.labelMedium!.copyWith(
                color: context.textTertiary,
                letterSpacing: 0.0,
              ),
            ),
            trailing: SwitchButton(
              value: telemetryConsent,
              onChanged: (value) {
                appLogger.info('Anonymous usage data consent changed: $value');
                ref.read(radianceSettingsProvider.notifier).setTelemetry(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ProxySetting extends StatelessWidget {
  const _ProxySetting({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.labelMedium!.copyWith(color: context.textTertiary),
          ),
        ),
        SelectableText(value, style: textTheme.labelLarge),
      ],
    );
  }
}
