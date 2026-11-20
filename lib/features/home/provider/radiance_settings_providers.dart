import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'radiance_settings_providers.g.dart';

/// Radiance's settings key for trying sites directly before the VPN.
const proxylessSettingKey = 'proxyless';

/// Reads the proxyless setting from radiance's settings, which leave it unset
/// until the user changes it; unset means on.
bool proxylessFromSettings(Map<String, dynamic> settings) {
  final v = settings[proxylessSettingKey];
  return v is bool ? v : true;
}

/// Holds radiance-backed VPN preferences in memory.
///
/// The notifier returns safe defaults synchronously from [build], then kicks
/// off a single background refresh that fetches the real values from the
/// native layer and updates state. Mutations update state in place on success,
/// avoiding an extra native round-trip just to re-read what we just wrote.
/// Consent choices made through [RadianceSettings.setTelemetry] in this app
/// process: the settings switch and the consent dialog. Developer mode's
/// "Send logs to SigNoz" switch reads it so a write it queued before a later
/// choice doesn't undo that choice.
int _consentChoices = 0;

int get consentChoices => _consentChoices;

Future<void> _consentWrites = Future<void>.value();

/// Runs a write that may change telemetry consent once every consent write
/// started before it has finished. Radiance's writes have no order of their
/// own, so this is what lets a later choice land last.
Future<T> runConsentWrite<T>(Future<T> Function() write) {
  final next = _consentWrites.then((_) => write());
  _consentWrites = next.then<void>((_) {}, onError: (Object _) {});
  return next;
}

/// The settings notifier that has read radiance, if any.
RadianceSettings? _loaded;

/// Tells the settings screen's consent switch, if it has read radiance at all,
/// that something outside it changed consent: to [consent] when the change is
/// known to have landed. It then reads consent again.
void refreshLoadedTelemetry({bool? consent}) {
  final loaded = _loaded;
  if (loaded != null) unawaited(loaded.consentChangedElsewhere(consent));
}

@Riverpod(keepAlive: true)
class RadianceSettings extends _$RadianceSettings {
  @override
  RadianceSettingsState build() {
    _loaded = this;
    ref.onDispose(() {
      if (identical(_loaded, this)) _loaded = null;
    });
    _refresh();
    return const RadianceSettingsState();
  }

  /// Fetches all settings in parallel and assigns a fresh state from the
  /// results. On a per-field fetch failure, falls back to the hardcoded
  /// default for that field. Each future is awaited into a named variable
  /// (positional-by-name, not positional-by-index) so adding another
  /// optional fetch later can't silently desync the read indices.
  Future<void> _refresh() async {
    // A consent read or choice that lands while this read runs is newer than
    // its answer, so it keeps its value (below).
    final telemetryRead = ++_telemetryReads;
    final consentChoices = _consentChoices;
    final svc = ref.read(lanternServiceProvider);
    final blockAdsF = svc.isBlockAdsEnabled();
    final routingF = svc.isSmartRoutingEnabled();
    final telemetryF = svc.isTelemetryEnabled();
    // Peer-proxy probe runs on every platform with a handler wired up:
    // Windows + Linux via FFI, macOS + Android + iOS via MethodChannel.
    // Manual port forwarding works on any home WiFi where the user owns
    // the router, so mobile is included rather than desktop-only.
    final peerF = svc.isPeerProxyEnabled();
    final unboundedF = svc.isUnboundedEnabled();
    // A Try Direct First or routing mode write that starts while this read
    // is in flight is newer than its answer, so it keeps its value (below).
    final proxylessWrites = _proxylessWrites;
    final routingRequests = _routingRequests;
    final settingsF = svc.getSettings();

    final blockAds = await blockAdsF;
    final routing = await routingF;
    final telemetry = await telemetryF;
    final peer = await peerF;
    final unbounded = await unboundedF;
    final settings = await settingsF;
    if (!ref.mounted) return;

    const defaults = RadianceSettingsState();
    final applyTelemetry = _acceptsTelemetryRead(telemetryRead, consentChoices);
    if (applyTelemetry && telemetry.isRight()) {
      _telemetryApplied = telemetryRead;
    }
    state = RadianceSettingsState(
      blockAds: blockAds.fold((_) => defaults.blockAds, (v) => v),
      routingMode: routingRequests != _routingRequests
          ? state.routingMode
          : routing.fold(
              (_) => defaults.routingMode,
              (smart) => smart ? RoutingMode.smart : RoutingMode.full,
            ),
      telemetry: applyTelemetry
          ? telemetry.fold((_) => defaults.telemetry, (v) => v)
          : state.telemetry,
      peerProxy: peer.fold((_) => defaults.peerProxy, (v) => v),
      unboundedEnabled: unbounded.fold(
        (_) => defaults.unboundedEnabled,
        (v) => v,
      ),
      proxyless: proxylessWrites != _proxylessWrites
          ? state.proxyless
          : settings.fold(
              (_) => defaults.proxyless,
              (s) => proxylessFromSettings(s),
            ),
    );
  }

  /// Counts Try Direct First writes started, so a settings read that began
  /// before one doesn't overwrite it.
  int _proxylessWrites = 0;

  /// Try Direct First writes run one at a time, in order, so the last one
  /// to finish is the last one made, and sets what the switch shows.
  Future<Either<Failure, Unit>> _proxylessChain = Future.value(right(unit));

  Future<void> setBlockAds(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setBlockAdsEnabled(value);
    if (!ref.mounted) return;
    result.fold(
      (err) => appLogger.error('setBlockAdsEnabled failed: ${err.error}'),
      (_) => state = state.copyWith(blockAds: value),
    );
  }

  /// The routing mode last asked for, which [state] shows once its write
  /// lands. Null when nothing is pending.
  RoutingMode? _routingTarget;

  /// Counts routing mode requests, so only the latest one's completion
  /// clears [_routingTarget]: an earlier request for the same mode finishing
  /// first must not, while the latest is still queued.
  int _routingRequests = 0;

  /// Routing mode writes run one at a time, in order, so the last one asked
  /// for is the one that sticks, as with Try Direct First.
  Future<Either<Failure, Unit>> _routingChain = Future.value(right(unit));

  /// The routing mode the user last chose: one still being written, or else
  /// the one in effect. Routing Mode stays open while a write runs, so its
  /// "already chosen" check reads this rather than [state].
  RoutingMode get requestedRoutingMode => _routingTarget ?? state.routingMode;

  Future<Either<Failure, Unit>> setRoutingMode(RoutingMode mode) {
    final request = ++_routingRequests;
    _routingTarget = mode;
    final next = _routingChain.then((_) => _writeRoutingMode(mode, request));
    _routingChain = next.catchError(
      (Object e) =>
          left<Failure, Unit>(Failure(error: '$e', localizedErrorMessage: '')),
    );
    return next;
  }

  Future<Either<Failure, Unit>> _writeRoutingMode(
    RoutingMode mode,
    int request,
  ) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setRoutingMode(mode == RoutingMode.smart);
    if (!ref.mounted) return right(unit);
    // Only the latest request settles what was asked for; on its failure,
    // what is in effect is what was there.
    final latest = request == _routingRequests;
    if (latest) _routingTarget = null;
    return result.fold(
      (err) async {
        appLogger.error('setRoutingMode failed: ${err.error}');
        // The screen may show a guess (the startup read can have been set
        // aside for this write): show the mode actually in effect.
        if (latest) {
          final current = await svc.isSmartRoutingEnabled();
          if (ref.mounted && request == _routingRequests) {
            current.fold(
              (_) {},
              (smart) => state = state.copyWith(
                routingMode: smart ? RoutingMode.smart : RoutingMode.full,
              ),
            );
          }
        }
        return left(err);
      },
      (_) async {
        state = state.copyWith(routingMode: mode);
        return right(unit);
      },
    );
  }

  /// Turns trying sites directly before the VPN on or off. Radiance switches
  /// the running tunnel without a restart.
  Future<Either<Failure, Unit>> setProxyless(bool value) {
    _proxylessWrites++;
    final next = _proxylessChain.then((_) => _writeProxyless(value));
    _proxylessChain = next.catchError(
      (Object e) =>
          left<Failure, Unit>(Failure(error: '$e', localizedErrorMessage: '')),
    );
    return next;
  }

  Future<Either<Failure, Unit>> _writeProxyless(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.patchSettings({proxylessSettingKey: value});
    if (!ref.mounted) return result;
    return result.fold(
      (err) async {
        appLogger.error('setProxyless failed: ${err.error}');
        // Radiance applies the live value before it saves, so a failed save
        // can still have switched proxyless. Show what it actually is.
        final current = await svc.getSettings();
        if (ref.mounted) {
          current.fold(
            (_) {},
            (s) => state = state.copyWith(proxyless: proxylessFromSettings(s)),
          );
        }
        return left(err);
      },
      (_) {
        state = state.copyWith(proxyless: value);
        return right(unit);
      },
    );
  }

  /// Consent reads, numbered in the order they start, and the newest one whose
  /// answer is shown. A read that fails applies nothing, so it doesn't stop an
  /// older read from landing.
  int _telemetryReads = 0;
  int _telemetryApplied = 0;

  /// Whether a consent read may apply: nothing newer has, and no consent
  /// choice was made after it started.
  bool _acceptsTelemetryRead(int read, int choices) =>
      read > _telemetryApplied && choices == _consentChoices;

  /// Re-reads telemetry consent, which Developer mode's "Send logs to SigNoz"
  /// switch turns on. Only the latest read applies, and none started before a
  /// later consent choice.
  Future<void> refreshTelemetry() async {
    if (!ref.mounted) return;
    final read = ++_telemetryReads;
    final choices = _consentChoices;
    final result = await ref.read(lanternServiceProvider).isTelemetryEnabled();
    if (!ref.mounted) return;
    result.fold((_) {}, (v) {
      if (!_acceptsTelemetryRead(read, choices)) return;
      _telemetryApplied = read;
      state = state.copyWith(telemetry: v);
    });
  }

  /// Consent changed outside this notifier, to [consent] when that's known.
  /// A read started before the change may answer with the old value, so none
  /// applies; a read started now confirms what radiance holds.
  Future<void> consentChangedElsewhere([bool? consent]) async {
    if (!ref.mounted) return;
    _telemetryApplied = _telemetryReads;
    if (consent != null) state = state.copyWith(telemetry: consent);
    await refreshTelemetry();
  }

  Future<void> setTelemetry(bool consent) async {
    _consentChoices++;
    final svc = ref.read(lanternServiceProvider);
    final result = await runConsentWrite(
      () => svc.updateTelemetryEvents(consent),
    );
    if (!ref.mounted) return;
    if (result.isLeft()) {
      result.mapLeft(
        (err) => appLogger.error('updateTelemetryEvents failed: ${err.error}'),
      );
      // This choice dropped every read started before it, so ask radiance
      // what it holds now.
      await refreshTelemetry();
      return;
    }
    // A consent read started before this write finished may answer with the
    // value it replaced.
    _telemetryApplied = ++_telemetryReads;
    state = state.copyWith(telemetry: consent);
  }

  /// Enable/disable the peer-proxy (Share My Connection) radiance
  /// setting. Returns the underlying Either so the caller can react to
  /// failure.
  ///
  /// That Either carries peer.Client.Start's own failure, not merely a
  /// failure to flip the setting: radiance runs Start synchronously under
  /// the settings patch and propagates its error out. So a caller sees the
  /// same failure twice — here and as a phase=error StatusEvent — and must
  /// not treat this one as a distinct, earlier class of problem. Internal
  /// logging still happens on failure for fire-and-forget call sites.
  Future<Either<Failure, Unit>> setPeerProxy(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setPeerProxyEnabled(value);
    if (!ref.mounted) return result;
    return result.fold(
      (err) {
        appLogger.error('setPeerProxyEnabled failed: ${err.error}');
        return left(err);
      },
      (_) {
        state = state.copyWith(peerProxy: value);
        return right(unit);
      },
    );
  }

  /// Mirror of setPeerProxy for the Unbounded toggle. Returns the
  /// Either so callers can react to failure (the Unbounded enable
  /// path in ShareNotifier uses this for UI rollback).
  Future<Either<Failure, Unit>> setUnboundedEnabled(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setUnboundedEnabled(value);
    if (!ref.mounted) return result;
    return result.fold(
      (err) {
        appLogger.error('setUnboundedEnabled failed: ${err.error}');
        return left(err);
      },
      (_) {
        state = state.copyWith(unboundedEnabled: value);
        return right(unit);
      },
    );
  }
}

/// Fetches whether user logged in via OAuth from radiance.
@riverpod
Future<bool> isOAuthLogin(Ref ref) async {
  final svc = ref.read(lanternServiceProvider);
  final result = await svc.isOAuthLogin();
  return result.fold((_) => false, (v) => v);
}

/// Fetches OAuth provider name from radiance.
@riverpod
Future<String> oAuthProvider(Ref ref) async {
  final svc = ref.read(lanternServiceProvider);
  final result = await svc.getOAuthProvider();
  return result.fold((_) => '', (v) => v);
}

/// Whether the user is an SSO user (OAuth login with a provider set).
@riverpod
Future<bool> isSSOUser(Ref ref) async {
  final isOAuth = await ref.watch(isOAuthLoginProvider.future);
  final provider = await ref.watch(oAuthProviderProvider.future);
  return isOAuth && provider.isNotEmpty;
}
