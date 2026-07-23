import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:share_plus/share_plus.dart';

bool _rewardDialogVisible = false;

/// Shows the "A friend upgraded to Pro" dialog when the user's data contains
/// converted referrals they haven't been congratulated for yet. Each converted
/// referral triggers the dialog exactly once; seen referrals are persisted in
/// local storage so the dialog never repeats.
Future<void> checkAndShowReferralReward(
  BuildContext context,
  UserResponseModel user,
) async {
  if (_rewardDialogVisible) return;

  final converted = user.legacyUserData.referrals
      .where((r) => r.converted)
      .toList();
  if (converted.isEmpty) return;

  final storage = sl<LocalStorageService>();
  final seen = storage.getSeenConvertedReferrals().toSet();
  final unseen = converted.where((r) => !seen.contains(r.userId)).toList();
  if (unseen.isEmpty) return;

  final newDays = unseen.fold<int>(0, (total, r) => total + r.bonusDaysEarned);
  // Floor by 30 days, matching referralBonusMonths. Conversions that haven't
  // yet added a full month stay unseen and accumulate toward the next dialog.
  final newMonths = newDays ~/ 30;
  if (newMonths == 0) return;
  final totalMonths = max(newMonths, user.legacyUserData.referralBonusMonths);

  if (!context.mounted) return;
  _rewardDialogVisible = true;
  try {
    _showReferralRewardDialog(
      context: context,
      newMonths: newMonths,
      totalMonths: totalMonths,
      referralCode: user.legacyUserData.referral.toUpperCase(),
    );

    // Persist only after the user dismisses the dialog. If the route cannot be
    // shown or the app exits first, the notification is retried next time.
    await storage.saveSeenConvertedReferrals(
      {...seen, ...converted.map((r) => r.userId)}.toList(),
    );
  } finally {
    _rewardDialogVisible = false;
  }
}

Future<void> _showReferralRewardDialog({
  required BuildContext context,
  required int newMonths,
  required int totalMonths,
  required String referralCode,
}) {
  final theme = Theme.of(context).textTheme;
  return AppDialog.customDialog(
    context: context,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(height: defaultSize),
        Icon(Icons.redeem, size: 40, color: context.textPrimary),
        SizedBox(height: defaultSize),
        Text(
          'referral_converted_title'.i18n,
          textAlign: TextAlign.center,
          style: theme.headlineSmall,
        ),
        SizedBox(height: defaultSize),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.bodyMedium!.copyWith(color: context.textSecondary),
            children: _messageSpans(context, newMonths, totalMonths),
          ),
        ),
      ],
    ),
    action: [
      AppTextButton(
        label: 'done'.i18n,
        textColor: context.textSecondary,
        onPressed: () {
          appRouter.pop();
        },
      ),
      AppTextButton(
        label: 'share_referral_code'.i18n,
        onPressed: () {
          appRouter.pop();
          SharePlus.instance.share(
            ShareParams(
              text: 'share_message_referral_code'.i18n.fill([referralCode]),
            ),
          );
        },
      ),
    ],
  );
}

String _monthsLabel(int months) => months == 1
    ? 'month_count'.i18n.fill([months])
    : 'months_count'.i18n.fill([months]);

List<TextSpan> _messageSpans(
  BuildContext context,
  int newMonths,
  int totalMonths,
) {
  final template = 'referral_converted_message'.i18n;
  final parts = template.split('%s');
  final values = [_monthsLabel(newMonths), _monthsLabel(totalMonths)];
  // If a translation has the wrong number of placeholders, fall back to the
  // plain filled template instead of dropping values or mangling the sentence.
  if (parts.length - 1 != values.length) {
    return [TextSpan(text: template.fill(values))];
  }
  final boldStyle = AppTextStyles.bodyMediumBold.copyWith(
    color: context.textPrimary,
  );
  final spans = <TextSpan>[];
  for (var i = 0; i < parts.length; i++) {
    spans.add(TextSpan(text: parts[i]));
    if (i < values.length && i < parts.length - 1) {
      spans.add(TextSpan(text: values[i], style: boldStyle));
    }
  }
  return spans;
}
