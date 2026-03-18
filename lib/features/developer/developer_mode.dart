import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/developer/notifier/developer_mode_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

import '../../core/services/injection_container.dart' show sl;

@RoutePage(name: 'DeveloperMode')
class DeveloperMode extends StatefulHookConsumerWidget {
  const DeveloperMode({super.key});

  @override
  ConsumerState<DeveloperMode> createState() => _DeveloperModeState();
}

class _DeveloperModeState extends ConsumerState<DeveloperMode> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(homeProvider).value;

    final developerMode = ref.watch(developerModeProvider);
    appLogger.info('Developer Mode settings: ${developerMode.toJson()}');
    final devNotifier = ref.read(developerModeProvider.notifier);
    final appSetting = ref.watch(appSettingProvider);
    final appSettingNotifier = ref.watch(appSettingProvider.notifier);
    final isStaging = appSetting.environment == 'stage' ||
        appSetting.environment == 'staging';

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
              ],
            ),
          ),
          SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (PlatformUtils.isAndroid)
                  AppTile(
                    label: 'Test Play Purchase',
                    trailing: SwitchButton(
                      value: developerMode.testPlayPurchaseEnabled,
                      onChanged: (bool? value) {
                        appLogger.info('Test Play Purchase toggled: $value');
                        devNotifier.updateDeveloperSettings(
                          developerMode.copyWith(
                            testPlayPurchaseEnabled: value ?? false,
                          ),
                        );
                      },
                    ),
                  ),
                DividerSpace(),
                if (!PlatformUtils.isIOS)
                  AppTile(
                    label: 'Stage Environment',
                    trailing: SwitchButton(
                      value: isStaging,
                      onChanged: (value) async {
                        await appSettingNotifier.setEnvironment(value);
                        if (!context.mounted) return;
                        AppDialog.dialog(
                          context: context,
                          title: 'Restart Required',
                          content:
                              'Please restart the app for the environment change to take effect.',
                          onPressed: () {
                            exit(0);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppTile(
              label: 'Reset App',
              onPressed: () => resetAppData(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> resetAppData(BuildContext context) async {
    final appDir = await AppStorageUtils.getAppDirectory();
    appDir.delete(recursive: true);
    sl<LocalStorageService>().deleteAll();
    AppDialog.errorDialog(
      context: context,
      title: 'Reset',
      content: 'Restart app to see changes.',
    );
  }
}
