import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../common/common.dart';

class ProBanner extends HookConsumerWidget {
  final String? title;

  final double topMargin;

  const ProBanner({super.key, this.title, this.topMargin = 16});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpired = ref.watch(isUserExpiredProvider);
    final textTheme = Theme.of(context).textTheme;
    // Small screens get the compact one-line
    // pill upsell instead of the full banner.
    if (isSmallScreen(context)) {
      return _CompactProBanner(isExpired: isExpired, topMargin: topMargin);
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
            isExpired
                ? 'pro_subscription_expired'.i18n
                : title ?? "get_unlimited_data".i18n,
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
            label: isExpired
                ? 'renew_pro_subscription'.i18n
                : 'upgrade_to_pro'.i18n,
            onPressed: () {
              appRouter.push(Plans());
            },
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
  const _CompactProBanner({required this.isExpired, required this.topMargin});

  final bool isExpired;
  final double topMargin;

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
                              ' - ${isExpired ? 'upsell_expired_suffix'.i18n : 'upsell_upgrade_suffix'.i18n}',
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
