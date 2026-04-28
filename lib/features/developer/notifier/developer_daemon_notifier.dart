import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/developer_daemon_state.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'developer_daemon_notifier.g.dart';

const List<String> kDaemonLogLevels = [
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
const String kEnvCountry = 'RADIANCE_COUNTRY';
const String kEnvVersion = 'RADIANCE_VERSION';
const String kEnvFeatureOverrides = 'RADIANCE_FEATURE_OVERRIDES';

/// Snapshot of dev-mode daemon state plus the IPC calls that mutate it.
/// Auto-disposed so each visit to the developer screen re-fetches fresh
/// state from the native layer.
@riverpod
class DeveloperDaemonNotifier extends _$DeveloperDaemonNotifier {
  @override
  DeveloperDaemonState build() {
    _load();
    return const DeveloperDaemonState();
  }

  Future<void> _load() async {
    final svc = ref.read(lanternServiceProvider);
    final (settingsResult, envResult) = await (
      svc.getSettings(),
      svc.getEnvVars(),
    ).wait;
    if (!ref.mounted) return;
    var next = state;
    settingsResult.match((_) {}, (settings) {
      final lvl = settings['log_level'];
      if (lvl is String && kDaemonLogLevels.contains(lvl)) {
        next = next.copyWith(logLevel: lvl);
      }
      final disabled = settings['config_fetch_disabled'];
      if (disabled is bool) {
        next = next.copyWith(configFetchEnabled: !disabled);
      }
    });
    envResult.match((_) {}, (env) {
      next = next.copyWith(
        country: env[kEnvCountry] ?? '',
        version: env[kEnvVersion] ?? '',
        featureOverrides: env[kEnvFeatureOverrides] ?? '',
      );
    });
    state = next.copyWith(loading: false);
  }

  Future<Either<Failure, Unit>> patchEnv(String key, String value) async {
    final result =
        await ref.read(lanternServiceProvider).patchEnvVars({key: value});
    if (!ref.mounted) return result.map((_) => unit);
    return result.map((_) {
      state = switch (key) {
        kEnvCountry => state.copyWith(country: value),
        kEnvVersion => state.copyWith(version: value),
        kEnvFeatureOverrides => state.copyWith(featureOverrides: value),
        _ => state,
      };
      return unit;
    });
  }

  Future<Either<Failure, Unit>> setLogLevel(String level) async {
    final result = await ref
        .read(lanternServiceProvider)
        .patchSettings({'log_level': level});
    if (!ref.mounted) return result;
    return result.map((_) {
      state = state.copyWith(logLevel: level);
      return unit;
    });
  }

  Future<Either<Failure, Unit>> setConfigFetchEnabled(bool enabled) async {
    final result = await ref
        .read(lanternServiceProvider)
        .patchSettings({'config_fetch_disabled': !enabled});
    if (!ref.mounted) return result;
    return result.map((_) {
      state = state.copyWith(configFetchEnabled: enabled);
      return unit;
    });
  }

  Future<Either<Failure, Unit>> sendConfigRequest() =>
      ref.read(lanternServiceProvider).sendConfigRequest();

  Future<Either<Failure, Unit>> runURLTests() =>
      ref.read(lanternServiceProvider).runURLTests();

  /// Pretty-printed JSON of current settings/env for the dev-mode "Show
  /// settings & env vars" dialog. Returns the first IPC error so callers
  /// can surface it via the standard failure snackbar.
  Future<Either<Failure, ({String settings, String env})>>
      fetchStateJson() async {
    final svc = ref.read(lanternServiceProvider);
    final (settingsResult, envResult) = await (
      svc.getSettings(),
      svc.getEnvVars(),
    ).wait;
    return settingsResult.flatMap((settings) {
      return envResult.map((env) {
        const encoder = JsonEncoder.withIndent('  ');
        return (settings: encoder.convert(settings), env: encoder.convert(env));
      });
    });
  }
}
