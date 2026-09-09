import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

import '../../core/common/common.dart';
import '../share_my_connection/action_mode_widgets.dart';
import '../share_my_connection/share_my_connection.dart';

/// Unbounded Settings sheet, reached from the main Settings menu. Two
/// toggles per the Figma spec
/// (figma.com/design/hNlyYToB5TnX9SDBFDYJTq?node-id=2403-19287):
///
/// 1. Auto-enable Unbounded — turn Unbounded on automatically when
///    Lantern is open. The actual auto-enable wiring lives
///    in the Home shell (or a VPN-status listener) and reads this flag.
/// 2. Hide Unbounded — collapse the Unbounded tab in the Home shell
///    when the user doesn't want to see it. With only the VPN tab
///    left, Home hides the tab strip entirely.
@RoutePage(name: 'UnboundedSetting')
class UnboundedSetting extends ConsumerWidget {
  const UnboundedSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingProvider.select((s) => s.unboundedHidden),
    );
    final notifier = ref.read(appSettingProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return BaseScreen(
      title: 'unbounded_settings_title'.i18n,
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const ActionModeAutoEnable(),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
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
          const SizedBox(height: 16),
          if (!PlatformUtils.isIOS) const UnboundedAdvancedCard(),
        ],
      ),
    );
  }
}
