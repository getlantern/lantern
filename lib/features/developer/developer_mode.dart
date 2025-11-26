import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/developer/notifier/developer_mode_notifier.dart';

import '../../core/services/injection_container.dart';

@RoutePage(name: 'DeveloperMode')
class DeveloperMode extends StatefulHookConsumerWidget {
  const DeveloperMode({super.key});

  @override
  ConsumerState<DeveloperMode> createState() => _DeveloperModeState();
}

class _DeveloperModeState extends ConsumerState<DeveloperMode> {
  @override
  Widget build(BuildContext context) {
    final user = sl<LocalStorageService>().getUser();
    appLogger.info('User info: $user');
    final developerMode = ref.watch(developerModeProvider);
    final devNotifier = ref.watch(developerModeProvider.notifier);
    return BaseScreen(
      title: 'developer_mode'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  onPressed: () => resetAppData(context),
                ),
                DividerSpace(),
                AppTile(
                  label: 'UserId',
                  trailing: AppTextButton(
                    label: user?.legacyUserData.userId?.toString() ?? 'N/A',

                  ),
                ),
                DividerSpace(),
                AppTile(
                  label: 'Status',
                  trailing: AppTextButton(
                    label: user?.legacyUserData.userLevel ?? 'N/A',

                  ),
                ),
                DividerSpace(),
                if (PlatformUtils.isMobile)
                  AppTile(
                    label: 'Test Play Purchase',
                    trailing: SwitchButton(
                      value: developerMode.testPlayPurchaseEnabled,
                      onChanged: (bool? value) {
                        appLogger.info('Test Play Purchase toggled: $value');
                        devNotifier.updateTestPlayPurchaseEnabled(
                          developerMode.copyWith(
                            testPlayPurchaseEnabled: value ?? false,
                          ),
                        );
                      },
                    ),
                  ),

                // AppTile(
                //   label: 'Test Stripe Purchase',
                //   trailing: SwitchButton(
                //     value: developerMode.testStripePurchaseEnabled,
                //     onChanged: (bool? value) {
                //       devNotifier.updateTestStripePurchaseEnabled(
                //         developerMode.copyWith(
                //           testPlayPurchaseEnabled: value ?? false,
                //         ),
                //       );
                //     },
                //   ),
                // ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> resetAppData(BuildContext context) async {
    final appDir = await AppStorageUtils.getAppDirectory();
    appDir.delete(recursive: true);
    AppDialog.errorDialog(
        context: context,
        title: 'Reset',
        content: 'Restart app the see changes.');
  }
}
