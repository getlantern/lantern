import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/personal_proxy_invite.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// The VPN tab's "Get a personal proxy", in the Pro banner's slot. While a
/// friend who claimed an invite waits on the user's approval, it says so, and
/// a tap opens that invite (startPersonalProxyInvite), even for a user who
/// already has a personal proxy.
class PersonalProxyBanner extends ConsumerWidget {
  const PersonalProxyBanner({super.key, this.topMargin = 16});

  final double topMargin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(personalProxyBannerVisibleProvider) &&
        !ref.watch(personalProxyWaitingProvider)) {
      return const SizedBox.shrink();
    }
    final waiting = ref.watch(
      helpersProvider.select((s) => s.view.awaitingApproval != null),
    );
    final title = waiting
        ? 'personal_proxy_banner_waiting_title'.i18n
        : 'personal_proxy_banner_title'.i18n;
    final body = waiting
        ? 'personal_proxy_banner_waiting_body'.i18n
        : 'personal_proxy_banner_body'.i18n;
    final textTheme = Theme.of(context).textTheme;
    if (isSmallScreen(context)) {
      return Padding(
        key: const Key('vpn.personal_proxy_banner'),
        padding: EdgeInsets.only(top: topMargin),
        child: _CompactPersonalProxyBanner(
          title: title,
          onTap: () => startPersonalProxyInvite(context, ref),
        ),
      );
    }
    return Padding(
      key: const Key('vpn.personal_proxy_banner'),
      padding: EdgeInsets.only(top: topMargin),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: AppTile(
          icon: AppImagePaths.handshake,
          label: title,
          subtitle: Text(
            body,
            style: textTheme.bodySmall!.copyWith(color: context.textSecondary),
          ),
          trailing: const AppImage(path: AppImagePaths.arrowForward),
          onPressed: () => startPersonalProxyInvite(context, ref),
        ),
      ),
    );
  }
}

/// The small-screen pill, styled like the compact Pro banner.
class _CompactPersonalProxyBanner extends StatelessWidget {
  const _CompactPersonalProxyBanner({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      key: const Key('vpn.personal_proxy_banner.compact'),
      color: context.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9999),
        side: BorderSide(color: context.borderDefault),
      ),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const ExcludeSemantics(
                    child: AppImage(
                      path: AppImagePaths.handshake,
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AutoSizeText(
                      title,
                      style: textTheme.bodyMedium!.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      minFontSize: 11,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const AppImage(
                    path: AppImagePaths.arrowForward,
                    width: 20,
                    height: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
