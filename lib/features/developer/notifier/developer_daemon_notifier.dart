import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/developer_daemon_state.dart';
import 'package:lantern/lantern/lantern_service.dart';
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

/// Radiance settings keys that dev-mode reads or writes. Mirrors the names in
/// radiance/common/settings/settings.go.
const String kSettingSendLogsToSigNoz = 'send_logs_to_signoz';
const String kSettingTelemetryEnabled = 'telemetry_enabled';

/// setSendLogsToSigNoz runs one write at a time, read-back included. On
/// desktop each PATCH runs in its own isolate, so overlapping writes could
/// land in a different order than the taps and leave upload in a state the
/// switch doesn't show. The queue lives outside the notifier, which is
/// disposed whenever the screen closes, so writes from a reopened screen
/// still line up behind ones queued before it closed.
Future<Either<Failure, Unit>> _sigNozChain = Future.value(right(unit));

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
    _loadSendLogsToSigNoz(svc);
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
      next = next.copyWith(
        telemetryEnabled: settings[kSettingTelemetryEnabled] == true,
      );
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

  // The switch's own read joins its write queue. A write queued before the
  // screen last closed may still be running, and nothing would update this
  // notifier when it lands, so read after it. A write made after the read
  // lands after it too, so the read can't overwrite it. The rest of the
  // screen loads without waiting on the queue.
  void _loadSendLogsToSigNoz(LanternService svc) {
    final read = _sigNozChain.then((_) async {
      final current = await svc.getSettings();
      if (ref.mounted) {
        current.fold(
          (_) {},
          (s) => state = state.copyWith(
            sendLogsToSigNoz: s[kSettingSendLogsToSigNoz] == true,
          ),
        );
      }
      return right<Failure, Unit>(unit);
    });
    _sigNozChain = read.catchError(
      (Object e) =>
          left<Failure, Unit>(Failure(error: '$e', localizedErrorMessage: '')),
    );
  }

  Future<Either<Failure, Unit>> setSendLogsToSigNoz(bool enabled) {
    // Read the service now: a queued write can run after the screen closes
    // and disposes this notifier, and it must still reach radiance.
    final svc = ref.read(lanternServiceProvider);
    final next = _sigNozChain.then((_) => _writeSendLogsToSigNoz(svc, enabled));
    _sigNozChain = next.catchError(
      (Object e) =>
          left<Failure, Unit>(Failure(error: '$e', localizedErrorMessage: '')),
    );
    return next;
  }

  Future<Either<Failure, Unit>> _writeSendLogsToSigNoz(
    LanternService svc,
    bool enabled,
  ) async {
    final result = await svc.patchSettings({kSettingSendLogsToSigNoz: enabled});
    if (!ref.mounted) return result;
    return result.fold(
      (err) async {
        // Radiance applies the live value before it saves, so a failed save
        // can still have switched upload. Show what it actually is.
        final current = await svc.getSettings();
        if (ref.mounted) {
          current.fold(
            (_) {},
            (s) => state = state.copyWith(
              sendLogsToSigNoz: s[kSettingSendLogsToSigNoz] == true,
            ),
          );
        }
        return left(err);
      },
      (_) {
        state = state.copyWith(sendLogsToSigNoz: enabled);
        return right(unit);
      },
    );
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
