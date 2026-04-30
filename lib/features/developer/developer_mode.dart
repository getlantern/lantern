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

const String _autoCountryOverride = '';

const List<_CountryOverrideOption> _countryOverrideOptions = [
  _CountryOverrideOption(_autoCountryOverride, 'Auto (real location)'),
  _CountryOverrideOption('CN', '🇨🇳 China'),
  _CountryOverrideOption('IR', '🇮🇷 Iran'),
  _CountryOverrideOption('RU', '🇷🇺 Russia'),
  _CountryOverrideOption('MO', '🇲🇴 Macao'),
  _CountryOverrideOption('HK', '🇭🇰 Hong Kong'),
  _CountryOverrideOption('US', '🇺🇸 United States'),
  _CountryOverrideOption('BG', '🇧🇬 Bulgaria'),
  _CountryOverrideOption('DE', '🇩🇪 Germany'),
  _CountryOverrideOption('GB', '🇬🇧 United Kingdom'),
];

class _CountryOverrideOption {
  final String code;
  final String label;

  const _CountryOverrideOption(this.code, this.label);
}

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
    final activeCountry = _activeCountryOverride(daemon);

    return BaseScreen(
      title: 'developer_mode'.i18n,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          InfoRow(text: 'developer_mode_note'.i18n),
          SizedBox(height: defaultSize),
          if (activeCountry != null) ...[
            _testingAsBanner(activeCountry, daemon.country.trim().isNotEmpty),
            SizedBox(height: defaultSize),
          ],
          _accountCard(user),
          SizedBox(height: defaultSize),
          _purchaseAndEnvironmentCard(),
          SizedBox(height: defaultSize),
          _countryOverrideCard(daemon),
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

  _CountryOverrideOption? _activeCountryOverride(DeveloperDaemonState daemon) {
    final envCountry = daemon.country.trim().toUpperCase();
    if (envCountry.isNotEmpty) {
      return _optionForCountry(envCountry);
    }
    final devCountry = daemon.devCountryOverride.trim().toUpperCase();
    return devCountry.isEmpty ? null : _optionForCountry(devCountry);
  }

  _CountryOverrideOption _optionForCountry(String code) {
    return _countryOverrideOptions.firstWhere(
      (option) => option.code == code,
      orElse: () => _CountryOverrideOption(code, code),
    );
  }

  List<_CountryOverrideOption> _optionsForCurrentCountry(String code) {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty ||
        _countryOverrideOptions.any(
          (option) => option.code == normalizedCode,
        )) {
      return _countryOverrideOptions;
    }
    return [
      ..._countryOverrideOptions,
      _CountryOverrideOption(normalizedCode, normalizedCode),
    ];
  }

  Widget _testingAsBanner(_CountryOverrideOption country, bool fromEnv) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.bgElevated,
        borderRadius: defaultBorderRadius,
        border: Border.all(color: context.actionPrimaryBg),
      ),
      child: Text(
        fromEnv
            ? 'Testing as: ${country.label} (RADIANCE_COUNTRY)'
            : 'Testing as: ${country.label}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.textPrimary,
          fontWeight: FontWeight.w600,
        ),
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

  Widget _countryOverrideCard(DeveloperDaemonState daemon) {
    final countryOptions = _optionsForCurrentCountry(daemon.devCountryOverride);
    final selectedCountry = daemon.devCountryOverride.trim().toUpperCase();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Country testing'),
          const SizedBox(height: 8),
          Text(
            'Config requests use this country until you switch back to Auto.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedCountry),
            initialValue: selectedCountry,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Testing country'),
            items: countryOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.code,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: daemon.loading
                ? null
                : (value) => _setCountryOverride(value ?? _autoCountryOverride),
          ),
          if (daemon.country.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'RADIANCE_COUNTRY is set and takes precedence.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setCountryOverride(String country) async {
    final normalizedCountry = country.trim().toUpperCase();
    final daemon = ref.read(developerDaemonProvider.notifier);
    final result = await daemon.setDevCountryOverride(normalizedCountry);
    if (!mounted) return;
    await result.match((failure) async => _snackFailure(failure), (_) async {
      final refresh = await daemon.sendConfigRequest();
      if (!mounted) return;
      refresh.match(
        _snackFailure,
        (_) => context.showSnackBar(
          normalizedCountry.isEmpty
              ? 'Country override cleared and config refreshed.'
              : 'Testing as: ${_optionForCountry(normalizedCountry).label}',
        ),
      );
    });
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
            label: 'RADIANCE_COUNTRY env (takes precedence)',
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
              result.match((f) => _snackFailure(f), _showStateDialog);
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
    result.match(_snackFailure, (_) => context.showSnackBar(successMessage));
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
