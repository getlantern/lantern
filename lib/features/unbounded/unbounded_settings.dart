import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

@RoutePage(name: 'UnboundedSettingsScreen')
class UnboundedSettingsScreen extends HookConsumerWidget {
  const UnboundedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSetting = ref.watch(appSettingProvider);
    final notifier = ref.read(appSettingProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return BaseScreen(
      title: 'Unbounded Settings',
      body: Column(
        children: [
          const SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppTile(
              label: 'Auto-enable Unbounded',
              subtitle: Text(
                'Turn on automatically when Lantern is open',
                style: textTheme.labelMedium!.copyWith(
                  color: context.textTertiary,
                ),
              ),
              icon: Icon(Icons.play_circle_outline, size: 22),
              trailing: Checkbox(
                value: appSetting.autoEnableUnbounded,
                onChanged: (val) =>
                    notifier.setAutoEnableUnbounded(val ?? false),
                activeColor: context.textLink,
              ),
              onPressed: () => notifier
                  .setAutoEnableUnbounded(!appSetting.autoEnableUnbounded),
            ),
          ),
          const SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppTile(
              label: 'Hide Unbounded',
              subtitle: Text(
                'Removes Unbounded from the UI',
                style: textTheme.labelMedium!.copyWith(
                  color: context.textTertiary,
                ),
              ),
              icon: Icon(Icons.visibility_off_outlined, size: 22),
              trailing: SwitchButton(
                value: appSetting.hideUnbounded,
                onChanged: notifier.setHideUnbounded,
              ),
              onPressed: () =>
                  notifier.setHideUnbounded(!appSetting.hideUnbounded),
            ),
          ),
        ],
      ),
    );
  }
}
