import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';

import '../common/common.dart';

/// The one Pro banner. Picks its own variant:
///  - free user: yellow "get unlimited data" upsell
///  - one-time Pro approaching its end (engineering#3845): escalating renewal
///    card — amber at 7–1 days left, red on the last day and once expired
///  - any other Pro user: renders nothing
class ProBanner extends HookConsumerWidget {
  final String? title;

  final double topMargin;

  const ProBanner({super.key, this.title, this.topMargin = 16});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renewal = ref.watch(proRenewalProvider);
    if (renewal.state != ProRenewalState.none) {
      return _renewalBanner(context, renewal);
    }
    if (ref.watch(isUserProProvider)) return const SizedBox.shrink();
    return _upsellBanner(context, ref);
  }

  Widget _upsellBanner(BuildContext context, WidgetRef ref) {
    final isExpired = ref.watch(isUserExpiredProvider);

    final textTheme = Theme.of(context).textTheme;
    // Small screens get the compact one-line
    // pill upsell instead of the full banner.
    if (isSmallScreen(context)) {
      return _CompactProBanner(
        isExpired: isExpired,
        topMargin: topMargin,
        title: title,
      );
    }
    return Container(
      margin: EdgeInsets.only(top: topMargin),
      padding: EdgeInsets.all(defaultSize),
      decoration: BoxDecoration(
        color: context.bgPromo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderPromo, width: 1),
      ),
      child: Column(
        children: [
          AutoSizeText(
            title ?? "get_unlimited_data".i18n,
            maxLines: 1,
            minFontSize: 14,
            maxFontSize: 16,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium!.copyWith(
              color: context.textPrimary,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          ProButton(
            label: 'upgrade_to_pro'.i18n,
            onPressed: () {
              appRouter.push(Plans());
            },
          ),
        ],
      ),
    );
  }

  Widget _renewalBanner(BuildContext context, ProRenewalInfo info) {
    final date = info.accessEndDate == null
        ? ''
        : AppDateFormats.monthDayOrdinal(info.accessEndDate!);

    final (String bannerTitle, String subtitle) = switch (info.state) {
      ProRenewalState.withinWeek => (
        info.daysLeft == 1
            ? 'pro_expires_one_day_left'.i18n.fill([date])
            : 'pro_expires_days_left'.i18n.fill([date, info.daysLeft]),
        'renewing_adds_time'.i18n,
      ),
      ProRenewalState.expiresToday => (
        'pro_ends_today'.i18n.fill([date]),
        'renew_now_keep_data'.i18n,
      ),
      // The expired date can be unknown (no lastExpiredOn/expiration on the
      // user record) — fall back to a dateless title instead of "expired on ".
      _ => (
        date.isEmpty
            ? 'pro_subscription_expired'.i18n
            : 'pro_expired_on'.i18n.fill([date]),
        'renew_now_get_back_data'.i18n,
      ),
    };

    final isError = info.state != ProRenewalState.withinWeek;
    final textColor = isError ? context.statusErrorText : context.textPrimary;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: topMargin),
      padding: EdgeInsets.all(defaultSize),
      decoration: BoxDecoration(
        color: isError ? context.statusErrorBg : context.bgPromo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? context.statusErrorBorder : context.borderPromo,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            bannerTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMediumBold.copyWith(color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall!.copyWith(
              color: isError ? context.statusErrorText : context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ProButton(
            label: 'renew_pro'.i18n,
            onPressed: () => appRouter.push(Plans()),
          ),
        ],
      ),
    );
  }
}

/// One-line 40px pill upsell for small screens (engineering#3046, Figma
/// node 2854-13197). Expired swaps to the status/error palette; the whole
/// pill opens Plans.
class _CompactProBanner extends StatelessWidget {
  const _CompactProBanner({
    required this.isExpired,
    required this.topMargin,
    this.title,
  });

  final bool isExpired;
  final double topMargin;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = isExpired
        ? context.statusErrorText
        : context.textSecondary;
    return Padding(
      padding: EdgeInsets.only(top: topMargin),
      child: Material(
        color: isExpired ? context.statusErrorBg : context.bgPromo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: BorderSide(
            color: isExpired ? context.statusErrorBorder : context.borderPromo,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: () => appRouter.push(Plans()),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const AppImage(
                  path: AppImagePaths.crown,
                  width: 24,
                  height: 24,
                  useThemeColor: false,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoSizeText.rich(
                    TextSpan(
                      style: textTheme.bodyMedium!.copyWith(color: textColor),
                      children: [
                        TextSpan(
                          text: isExpired
                              ? 'renew_pro'.i18n
                              : 'upgrade_to_pro'.i18n,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              ' - ${isExpired ? 'upsell_expired_suffix'.i18n : title ?? 'upsell_upgrade_suffix'.i18n}',
                        ),
                      ],
                    ),
                    maxLines: 1,
                    minFontSize: 11,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
