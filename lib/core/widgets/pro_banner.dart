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

  const ProBanner({
    super.key,
    this.title,
    this.topMargin = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renewal = ref.watch(proRenewalProvider);
    if (renewal.state != ProRenewalState.none) {
      return _renewalBanner(context, renewal);
    }
    if (ref.watch(isUserProProvider)) return const SizedBox.shrink();
    return _upsellBanner(context);
  }

  Widget _upsellBanner(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
