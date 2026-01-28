import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../common/common.dart';

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
    final isExpired = ref.watch(isUserExpiredProvider);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: EdgeInsets.only(top: topMargin),
      padding: EdgeInsets.all(defaultSize),
      decoration: BoxDecoration(
          color: AppColors.yellow1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.yellow4, width: 1)),
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
              color: AppColors.gray9,
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
