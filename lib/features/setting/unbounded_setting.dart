import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/share_my_connection/share_my_connection.dart';

import '../../core/common/common.dart';

/// Unbounded Settings sheet, reached from the main Settings menu. Two
/// toggles per the Figma spec
/// (figma.com/design/hNlyYToB5TnX9SDBFDYJTq?node-id=2403-19287):
///
/// 1. Auto-enable Unbounded — turn Unbounded on automatically when
///    Lantern (VPN) is connected. The actual auto-enable wiring lives
///    in the Home shell (or a VPN-status listener) and reads this flag.
/// 2. Hide Unbounded — collapse the Unbounded tab in the Home shell
///    when the user doesn't want to see it. With only the VPN tab
///    left, Home hides the tab strip entirely.
///
/// Manual port forwarding sits here rather than on the tab because the spec's
/// Unbounded screen has no Advanced section.
@RoutePage(name: 'UnboundedSetting')
class UnboundedSetting extends ConsumerWidget {
  const UnboundedSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoEnable = ref.watch(
      appSettingProvider.select((s) => s.unboundedAutoEnable),
    );
    final hidden = ref.watch(
      appSettingProvider.select((s) => s.unboundedHidden),
    );
    final notifier = ref.read(appSettingProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return BaseScreen(
      title: 'unbounded_settings_title'.i18n,
      body: ListView(
        children: [
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTile(
                  label: 'auto_enable_unbounded'.i18n,
                  subtitle: Text(
                    'auto_enable_unbounded_subtitle'.i18n,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textTertiary,
                      letterSpacing: 0.0,
                    ),
                  ),
                  icon: AppImagePaths.share,
                  trailing: SwitchButton(
                    value: autoEnable,
                    onChanged: (v) => _setAutoEnable(context, ref, v),
                  ),
                  onPressed: () =>
                      _setAutoEnable(context, ref, !autoEnable),
                ),
                DividerSpace(),
                AppTile(
                  label: 'hide_unbounded'.i18n,
                  subtitle: Text(
                    'hide_unbounded_subtitle'.i18n,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textTertiary,
                      letterSpacing: 0.0,
                    ),
                  ),
                  icon: const Icon(Icons.visibility_off_outlined),
                  trailing: SwitchButton(
                    value: hidden,
                    onChanged: notifier.setUnboundedHidden,
                  ),
                  onPressed: () => notifier.setUnboundedHidden(!hidden),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const UnboundedAdvancedCard(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Turning auto-start on is a start path like any other, so it collects the
  /// same consent. Without this, enabling it here would let autoStart share on
  /// the next launch for a user who was never shown the disclosure — and
  /// autoStart itself cannot prompt.
  Future<void> _setAutoEnable(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifier = ref.read(appSettingProvider.notifier);
    if (!enabled) {
      notifier.setUnboundedAutoEnable(false);
      return;
    }
    final consented =
        await ref.read(shareProvider.notifier).ensureConsent(context);
    if (!consented) return;
    notifier.setUnboundedAutoEnable(true);
  }
}
