import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';

class ActionModeAutoEnable extends ConsumerWidget {
  const ActionModeAutoEnable({
    super.key,
    this.card = true,
    this.below,
    this.startNow = false,
  });

  /// Whether the row sits in its own card, as in Settings. The Welcome to
  /// Action Mode dialog shows it bare.
  final bool card;

  /// A row sharing the card, under a divider.
  final Widget? below;

  /// Checking the box also turns Action Mode on now, for the friend just
  /// paired: the volunteer's success dialog.
  final bool startNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      appSettingProvider.select((s) => s.unboundedAutoEnable),
    );
    Future<void> change(bool? value) async {
      if (value == null) return;
      final share = ref.read(shareProvider.notifier);
      final on = await share.setAutoEnable(context, value);
      if (on && startNow && context.mounted) {
        // Unchecked again while the start's checks run: nothing starts.
        await share.startForHelper(ref, requireAutoEnable: true);
      }
    }

    final tile = AppTile(
      label: 'auto_enable_unbounded'.i18n,
      subtitle: Text(
        'auto_enable_unbounded_subtitle'.i18n,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: context.textTertiary),
      ),
      icon: AppImagePaths.actionModeAuto,
      trailing: Checkbox(
        key: const Key('action-mode.auto-enable'),
        value: enabled,
        activeColor: context.textLink,
        checkColor: context.bgElevated,
        onChanged: change,
      ),
      onPressed: () => unawaited(change(!enabled)),
      // Bare, it has the dialog's width only: no inset, and the dialog's
      // body size, so the label fits.
      contentPadding: card ? null : EdgeInsets.zero,
      tileTextStyle: card
          ? null
          : Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textPrimary),
    );
    if (!card) return tile;
    final next = below;
    return AppCard(
      padding: EdgeInsets.zero,
      child: next == null
          ? tile
          : Column(children: [tile, const DividerSpace(), next]),
    );
  }
}
