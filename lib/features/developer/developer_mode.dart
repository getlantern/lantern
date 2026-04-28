import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/developer_daemon_state.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/developer/notifier/developer_daemon_notifier.dart';
import 'package:lantern/features/developer/notifier/developer_mode_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

import '../../core/services/injection_container.dart' show sl;

enum _DevAction { sendConfig, runURLTests, showState }

@RoutePage(name: 'DeveloperMode')
class DeveloperMode extends StatefulHookConsumerWidget {
  const DeveloperMode({super.key});

  @override
  ConsumerState<DeveloperMode> createState() => _DeveloperModeState();
}

class _DeveloperModeState extends ConsumerState<DeveloperMode> {
  final _countryController = TextEditingController();
  final _versionController = TextEditingController();
  final _featureOverridesController = TextEditingController();

  // Action tiles currently awaiting an IPC reply — drives spinner + blocks
  // double-taps while the call is in flight.
  final Set<_DevAction> _runningActions = {};

  @override
  void dispose() {
    _countryController.dispose();
    _versionController.dispose();
    _featureOverridesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Seed controllers from the daemon snapshot once the initial fetch
    // completes; subsequent state changes don't overwrite user edits.
    ref.listen<DeveloperDaemonState>(developerDaemonProvider, (prev, next) {
      if ((prev?.loading ?? true) && !next.loading) {
        _countryController.text = next.country;
        _versionController.text = next.version;
        _featureOverridesController.text = next.featureOverrides;
      }
    });

    final user = ref.watch(homeProvider).value;
    final daemon = ref.watch(developerDaemonProvider);

    return BaseScreen(
      title: 'developer_mode'.i18n,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          InfoRow(text: 'developer_mode_note'.i18n),
          SizedBox(height: defaultSize),
          _accountCard(user),
          SizedBox(height: defaultSize),
          _purchaseAndEnvironmentCard(),
          SizedBox(height: defaultSize),
          _overridesCard(),
          SizedBox(height: defaultSize),
          _daemonSettingsCard(daemon),
          SizedBox(height: defaultSize),
          _actionsCard(),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }

  Widget _accountCard(UserResponseModel? user) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AppTile(
            label: 'UserId',
            trailing: AppTextButton(
              label: user?.legacyUserData.userId.toString() ?? 'N/A',
            ),
          ),
          DividerSpace(),
          AppTile(
            label: 'Status',
            trailing: AppTextButton(
              label: user?.legacyUserData.userLevel ?? 'N/A',
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseAndEnvironmentCard() {
    final developerMode = ref.watch(developerModeProvider);
    final devNotifier = ref.read(developerModeProvider.notifier);
    final environment = ref.watch(
      appSettingProvider.select((s) => s.environment),
    );
    final isStaging = environment == 'stage' || environment == 'staging';
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (PlatformUtils.isAndroid)
            AppTile(
              label: 'Test Play Purchase',
              trailing: SwitchButton(
                value: developerMode.testPlayPurchaseEnabled,
                onChanged: (bool? value) {
                  devNotifier.updateDeveloperSettings(
                    developerMode.copyWith(
                      testPlayPurchaseEnabled: value ?? false,
                    ),
                  );
                },
              ),
            ),
          if (PlatformUtils.isAndroid) DividerSpace(),
          if (!PlatformUtils.isIOS)
            AppTile(
              label: 'Stage Environment',
              trailing: SwitchButton(
                value: isStaging,
                onChanged: (value) async {
                  await ref
                      .read(appSettingProvider.notifier)
                      .setEnvironment(value);
                  if (!mounted) return;
                  AppDialog.dialog(
                    context: context,
                    title: 'Restart Required',
                    content:
                        'Please restart the app for the environment change to take effect.',
                    onPressed: () => exit(0),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _overridesCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Radiance env overrides'),
          const SizedBox(height: 8),
          _envField(
            label: 'Country (e.g. IR, CN)',
            controller: _countryController,
            envKey: kEnvCountry,
          ),
          const SizedBox(height: 8),
          _envField(
            label: 'App version',
            controller: _versionController,
            envKey: kEnvVersion,
          ),
          const SizedBox(height: 8),
          _envField(
            label: 'Feature overrides (JSON)',
            controller: _featureOverridesController,
            envKey: kEnvFeatureOverrides,
          ),
        ],
      ),
    );
  }

  Widget _envField({
    required String label,
    required TextEditingController controller,
    required String envKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextField(
            label: label,
            hintText: '',
            controller: controller,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: AppTextButton(
            label: 'Apply',
            onPressed: () => _runAndReport(
              () => ref
                  .read(developerDaemonProvider.notifier)
                  .patchEnv(envKey, controller.text.trim()),
              '$envKey set to "${controller.text.trim()}"',
            ),
          ),
        ),
      ],
    );
  }

  Widget _daemonSettingsCard(DeveloperDaemonState daemon) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Log level'),
                DropdownButton<String>(
                  value: kDaemonLogLevels.contains(daemon.logLevel)
                      ? daemon.logLevel
                      : 'info',
                  items: kDaemonLogLevels
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: daemon.loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          _runAndReport(
                            () => ref
                                .read(developerDaemonProvider.notifier)
                                .setLogLevel(value),
                            'Log level set to $value',
                          );
                        },
                ),
              ],
            ),
          ),
          DividerSpace(),
          AppTile(
            label: 'Config fetch enabled',
            trailing: SwitchButton(
              value: daemon.configFetchEnabled,
              onChanged: (value) {
                if (daemon.loading) return;
                _runAndReport(
                  () => ref
                      .read(developerDaemonProvider.notifier)
                      .setConfigFetchEnabled(value),
                  'Config fetch ${value ? 'enabled' : 'disabled'}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    final daemon = ref.read(developerDaemonProvider.notifier);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _asyncActionTile(
            id: _DevAction.sendConfig,
            label: 'Send config request',
            icon: Icons.cloud_download_outlined,
            action: () =>
                _runAndReport(daemon.sendConfigRequest, 'Config request sent'),
          ),
          DividerSpace(),
          _asyncActionTile(
            id: _DevAction.runURLTests,
            label: 'Run URL tests',
            icon: Icons.speed_outlined,
            action: () =>
                _runAndReport(daemon.runURLTests, 'URL tests triggered'),
          ),
          DividerSpace(),
          _asyncActionTile(
            id: _DevAction.showState,
            label: 'Show settings & env vars',
            icon: Icons.info_outline,
            action: () async {
              final result = await daemon.fetchStateJson();
              result.match(
                (f) => _snackFailure(f),
                _showStateDialog,
              );
            },
          ),
          DividerSpace(),
          AppTile(
            label: 'Reset App',
            icon: Icons.restart_alt,
            onPressed: _resetAppData,
          ),
        ],
      ),
    );
  }

  Widget _asyncActionTile({
    required _DevAction id,
    required String label,
    required IconData icon,
    required Future<void> Function() action,
  }) {
    final running = _runningActions.contains(id);
    return AppTile(
      label: label,
      icon: icon,
      loading: running,
      onPressed: running
          ? null
          : () async {
              setState(() => _runningActions.add(id));
              try {
                await action();
              } finally {
                if (mounted) setState(() => _runningActions.remove(id));
              }
            },
    );
  }

  void _showStateDialog(({String settings, String env}) data) {
    if (!mounted) return;
    AppDialog.customDialog(
      context: context,
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Settings & env vars',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              SelectableText(
                'Settings:\n${data.settings}\n\nEnv:\n${data.env}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      action: [
        AppTextButton(
          label: 'close'.i18n,
          onPressed: () => appRouter.maybePop(),
        ),
      ],
    );
  }

  /// Runs [op] and shows [successMessage] or the failure's localized message
  /// via snackbar. Used by every notifier-driven action in this screen.
  Future<void> _runAndReport(
    Future<Either<Failure, Unit>> Function() op,
    String successMessage,
  ) async {
    final result = await op();
    if (!mounted) return;
    result.match(
      _snackFailure,
      (_) => context.showSnackBar(successMessage),
    );
  }

  void _snackFailure(Failure f) {
    if (!mounted) return;
    context.showSnackBar('Failed: ${f.localizedErrorMessage}');
  }

  Future<void> _resetAppData() async {
    final appDir = await AppStorageUtils.getAppDirectory();
    appDir.delete(recursive: true);
    sl<LocalStorageService>().deleteAll();
    if (!mounted) return;
    AppDialog.errorDialog(
      context: context,
      title: 'Reset',
      content: 'Restart app to see changes.',
    );
  }
}
