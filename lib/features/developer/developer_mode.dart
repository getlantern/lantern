import 'dart:convert';
import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/developer/notifier/developer_mode_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

import '../../core/services/injection_container.dart' show sl;

const List<String> _logLevels = [
  'trace',
  'debug',
  'info',
  'warn',
  'error',
  'fatal',
  'panic',
  'disable',
];

/// Radiance env var keys that dev-mode exposes. Mirrors the names in
/// radiance/common/env/env.go.
const String _envCountry = 'RADIANCE_COUNTRY';
const String _envVersion = 'RADIANCE_VERSION';
const String _envFeatureOverrides = 'RADIANCE_FEATURE_OVERRIDES';

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

  String _logLevel = 'info';
  // Track daemon state; `null` means unknown/not yet loaded.
  bool? _configFetchEnabled;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromDaemon());
  }

  @override
  void dispose() {
    _countryController.dispose();
    _versionController.dispose();
    _featureOverridesController.dispose();
    super.dispose();
  }

  Future<void> _loadFromDaemon() async {
    final service = ref.read(lanternServiceProvider);
    final settingsResult = await service.getSettings();
    final envResult = await service.getEnvVars();
    if (!mounted) return;
    setState(() {
      settingsResult.match((_) {}, (settings) {
        final lvl = settings['log_level'];
        if (lvl is String && _logLevels.contains(lvl)) _logLevel = lvl;
        final disabled = settings['config_fetch_disabled'];
        if (disabled is bool) _configFetchEnabled = !disabled;
      });
      envResult.match((_) {}, (env) {
        _countryController.text = env[_envCountry] ?? '';
        _versionController.text = env[_envVersion] ?? '';
        _featureOverridesController.text = env[_envFeatureOverrides] ?? '';
      });
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(homeProvider).value;

    final developerMode = ref.watch(developerModeProvider);
    final devNotifier = ref.read(developerModeProvider.notifier);
    final appSetting = ref.watch(appSettingProvider);
    final appSettingNotifier = ref.watch(appSettingProvider.notifier);
    final isStaging = appSetting.environment == 'stage' ||
        appSetting.environment == 'staging';

    return BaseScreen(
      title: 'developer_mode'.i18n,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          InfoRow(text: 'developer_mode_note'.i18n),
          SizedBox(height: defaultSize),
          _accountCard(user),
          SizedBox(height: defaultSize),
          _purchaseAndEnvironmentCard(
            developerMode: developerMode,
            devNotifier: devNotifier,
            isStaging: isStaging,
            appSettingNotifier: appSettingNotifier,
          ),
          SizedBox(height: defaultSize),
          _overridesCard(),
          SizedBox(height: defaultSize),
          _daemonSettingsCard(),
          SizedBox(height: defaultSize),
          _actionsCard(devNotifier),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }

  Widget _accountCard(dynamic user) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
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
        ],
      ),
    );
  }

  Widget _purchaseAndEnvironmentCard({
    required dynamic developerMode,
    required dynamic devNotifier,
    required bool isStaging,
    required dynamic appSettingNotifier,
  }) {
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
                  await appSettingNotifier.setEnvironment(value);
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
          const Text(
            'Radiance env overrides',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _envField(
            label: 'Country (e.g. IR, CN)',
            controller: _countryController,
            envKey: _envCountry,
          ),
          const SizedBox(height: 8),
          _envField(
            label: 'App version',
            controller: _versionController,
            envKey: _envVersion,
          ),
          const SizedBox(height: 8),
          _envField(
            label: 'Feature overrides (JSON)',
            controller: _featureOverridesController,
            envKey: _envFeatureOverrides,
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
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => _applyEnv(envKey, controller.text.trim()),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _daemonSettingsCard() {
    final configFetchEnabled = _configFetchEnabled ?? true;
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
                  value: _logLevels.contains(_logLevel) ? _logLevel : 'info',
                  items: _logLevels
                      .map(
                        (l) => DropdownMenuItem(value: l, child: Text(l)),
                      )
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          _applyLogLevel(value);
                        },
                ),
              ],
            ),
          ),
          DividerSpace(),
          AppTile(
            label: 'Config fetch enabled',
            trailing: SwitchButton(
              value: configFetchEnabled,
              onChanged: (value) {
                if (_loading) return;
                _applyConfigFetchEnabled(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(dynamic devNotifier) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AppTile(
            label: 'Send config request',
            icon: Icons.cloud_download_outlined,
            onPressed: _sendConfigRequest,
          ),
          DividerSpace(),
          AppTile(
            label: 'Run URL tests',
            icon: Icons.speed_outlined,
            onPressed: _runURLTests,
          ),
          DividerSpace(),
          AppTile(
            label: 'Show settings & env vars',
            icon: Icons.info_outline,
            onPressed: _showState,
          ),
          DividerSpace(),
          AppTile(
            label: 'Reset App',
            icon: Icons.restart_alt,
            onPressed: _resetAppData,
          ),
          DividerSpace(),
          AppTile(
            label: 'Disable developer mode',
            icon: Icons.lock_outline,
            onPressed: () async {
              await devNotifier.setEnabled(false);
              if (!mounted) return;
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _applyEnv(String key, String value) async {
    final service = ref.read(lanternServiceProvider);
    final result = await service.patchEnvVars({key: value});
    _showResult(result, '$key set to "$value"');
  }

  Future<void> _applyLogLevel(String level) async {
    final service = ref.read(lanternServiceProvider);
    final result = await service.patchSettings({'log_level': level});
    result.match(
      (f) => _snack('Failed: ${f.localizedErrorMessage}'),
      (_) {
        setState(() => _logLevel = level);
        _snack('Log level set to $level');
      },
    );
  }

  Future<void> _applyConfigFetchEnabled(bool enabled) async {
    final service = ref.read(lanternServiceProvider);
    final result =
        await service.patchSettings({'config_fetch_disabled': !enabled});
    result.match(
      (f) => _snack('Failed: ${f.localizedErrorMessage}'),
      (_) {
        setState(() => _configFetchEnabled = enabled);
        _snack('Config fetch ${enabled ? 'enabled' : 'disabled'}');
      },
    );
  }

  Future<void> _sendConfigRequest() async {
    final service = ref.read(lanternServiceProvider);
    final result = await service.sendConfigRequest();
    _showResult(result, 'Config request sent');
  }

  Future<void> _runURLTests() async {
    final service = ref.read(lanternServiceProvider);
    final result = await service.runURLTests();
    _showResult(result, 'URL tests triggered');
  }

  Future<void> _showState() async {
    final service = ref.read(lanternServiceProvider);
    final settings = await service.getSettings();
    final env = await service.getEnvVars();
    if (!mounted) return;
    final settingsJson = settings.match(
      (f) => 'Error: ${f.localizedErrorMessage}',
      (s) => const JsonEncoder.withIndent('  ').convert(s),
    );
    final envJson = env.match(
      (f) => 'Error: ${f.localizedErrorMessage}',
      (e) => const JsonEncoder.withIndent('  ').convert(e),
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settings & env vars'),
        content: SingleChildScrollView(
          child: SelectableText(
            'Settings:\n$settingsJson\n\nEnv:\n$envJson',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResult<T>(Either<Failure, T> result, String successMessage) {
    result.match(
      (f) => _snack('Failed: ${f.localizedErrorMessage}'),
      (_) => _snack(successMessage),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
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
