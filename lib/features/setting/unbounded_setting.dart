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
                  icon: AppImagePaths.autoMode,
                  trailing: SwitchButton(
                    value: autoEnable,
                    onChanged: (v) =>
                        ref.read(shareProvider.notifier).setAutoEnable(context, v),
                  ),
                  onPressed: () => ref
                      .read(shareProvider.notifier)
                      .setAutoEnable(context, !autoEnable),
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
                  icon: AppImagePaths.visibilityOff,
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
          // The only knob in here is the manually forwarded port, which
          // exists to select the peer-proxy mode. iOS never enters that mode,
          // so the field would report a setting as active that nothing can
          // act on.
          if (!PlatformUtils.isIOS) ...[
            const UnboundedAdvancedCard(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
