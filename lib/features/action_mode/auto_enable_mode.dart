import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';

class ActionModeAutoEnable extends ConsumerWidget {
  const ActionModeAutoEnable({super.key, this.card = true});

  /// Whether the row sits in its own card, as in Settings. The Welcome to
  /// Action Mode dialog shows it bare.
  final bool card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      appSettingProvider.select((s) => s.unboundedAutoEnable),
    );
    void change(bool? value) {
      if (value != null) {
        ref.read(shareProvider.notifier).setAutoEnable(context, value);
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
      onPressed: () => change(!enabled),
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
    return AppCard(padding: EdgeInsets.zero, child: tile);
  }
}
