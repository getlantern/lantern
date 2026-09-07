import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

bool _shownThisSession = false;

/// Day-of renewal popup (engineering#3845): on app open, when a one-time Pro
/// purchase ends today, show a single popup for the session. Dismissing it
/// keeps it away until the next app start; renewing routes to the plans page.
Future<void> checkAndShowProRenewalPopup(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_shownThisSession) return;
  final renewal = ref.read(proRenewalProvider);
  if (renewal.state != ProRenewalState.expiresToday) return;

  _shownThisSession = true;
  final theme = Theme.of(context).textTheme;
  await AppDialog.customDialog(
    context: context,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(height: defaultSize),
        Icon(Icons.schedule, size: 40, color: context.textPrimary),
        SizedBox(height: defaultSize),
        Text(
          'pro_expires_today_title'.i18n,
          textAlign: TextAlign.center,
          style: theme.headlineSmall,
        ),
        SizedBox(height: defaultSize),
        Text(
          'pro_expires_today_popup_message'.i18n,
          textAlign: TextAlign.center,
          style: theme.bodyMedium!.copyWith(color: context.textSecondary),
        ),
      ],
    ),
    action: [
      PrimaryButton(
        label: 'renew_now'.i18n,
        onPressed: () {
          appRouter.pop();
          appRouter.push(Plans());
        },
      ),
      SecondaryButton(
        label: 'dismiss'.i18n,
        onPressed: () => appRouter.pop(),
      ),
    ],
  );
}
