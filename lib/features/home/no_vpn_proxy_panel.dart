import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/common/stealth_no_vpn_proxy.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

class NoVpnProxyPanel extends HookConsumerWidget {
  const NoVpnProxyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(vpnProvider);
    final active = status == VPNStatus.connected;
    final busy =
        status == VPNStatus.connecting || status == VPNStatus.disconnecting;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('proxy_mode'.i18n, style: textTheme.titleMedium),
              ),
              Text(
                active ? 'enabled'.i18n : 'disabled'.i18n,
                style: textTheme.titleMedium!.copyWith(
                  color: active
                      ? context.statusSuccessText
                      : context.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'proxy_mode_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
          ),
          SizedBox(height: 12),
          _ProxyRow(
            label: 'socks5_proxy'.i18n,
            value: StealthNoVpnProxy.address,
          ),
          SizedBox(height: 6),
          _ProxyRow(
            label: 'http_connect_proxy'.i18n,
            value: StealthNoVpnProxy.address,
          ),
          SizedBox(height: 12),
          AppTextButton(
            label: active ? 'stop_proxy'.i18n : 'start_proxy'.i18n,
            onPressed: busy
                ? null
                : () async {
                    final notifier = ref.read(vpnProvider.notifier);
                    final result = active
                        ? await notifier.stopVPN()
                        : await notifier.startVPN(skipConflictCheck: true);
                    if (!context.mounted) {
                      return;
                    }
                    result.match(
                      (failure) =>
                          context.showSnackBar(failure.localizedErrorMessage),
                      (_) => null,
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _ProxyRow extends StatelessWidget {
  const _ProxyRow({required this.label, required this.value});

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
