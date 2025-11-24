import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/developer/notifier/developer_mode_notifier.dart';

@RoutePage(name: 'DeveloperMode')
class DeveloperMode extends StatefulHookConsumerWidget {
  const DeveloperMode({super.key});

  @override
  ConsumerState<DeveloperMode> createState() => _DeveloperModeState();
}

class _DeveloperModeState extends ConsumerState<DeveloperMode> {
  @override
  Widget build(BuildContext context) {
    final developerMode = ref.watch(developerModeProvider);
    final devNotifier = ref.watch(developerModeProvider.notifier);
    return BaseScreen(
      title: 'developer_mode'.i18n,
      body: Column(
        children: [
          InfoRow(text: 'developer_mode_note'.i18n),
          SizedBox(height: defaultSize),
          AppCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                AppTile(
                  label: 'Reset App',
                ),
                DividerSpace(),
                if (PlatformUtils.isMobile)
                  AppTile(
                    label: 'Test Play Purchase',
                    trailing: SwitchButton(
                      value: developerMode.testPlayPurchaseEnabled,
                      onChanged: (bool? value) {
                        devNotifier.updateTestPlayPurchaseEnabled(
                          developerMode.copyWith(
                            testPlayPurchaseEnabled: value ?? false,
                          ),
                        );
                      },
                    ),
                  ),
                DividerSpace(),
                AppTile(
                  label: 'Test Stripe Purchase',
                  trailing: SwitchButton(
                    value: developerMode.testStripePurchaseEnabled,
                    onChanged: (bool? value) {
                      devNotifier.updateTestStripePurchaseEnabled(
                        developerMode.copyWith(
                          testPlayPurchaseEnabled: value ?? false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
