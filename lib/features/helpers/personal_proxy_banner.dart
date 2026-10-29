import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/personal_proxy_invite.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// The VPN tab's "Get a personal proxy", in the Pro banner's slot.
class PersonalProxyBanner extends ConsumerWidget {
  const PersonalProxyBanner({super.key, this.topMargin = 16});

  final double topMargin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(personalProxyBannerVisibleProvider)) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('vpn.personal_proxy_banner'),
      padding: EdgeInsets.only(top: topMargin),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: AppTile(
          icon: AppImagePaths.handshake,
          label: 'personal_proxy_banner_title'.i18n,
          subtitle: Text(
            'personal_proxy_banner_body'.i18n,
            style: textTheme.bodySmall!.copyWith(color: context.textSecondary),
          ),
          trailing: const AppImage(path: AppImagePaths.arrowForward),
          onPressed: () => startPersonalProxyInvite(context, ref),
        ),
      ),
    );
  }
}
