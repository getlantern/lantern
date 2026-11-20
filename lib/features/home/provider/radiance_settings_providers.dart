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
@Riverpod(keepAlive: true)
class RadianceSettings extends _$RadianceSettings {
  @override
  RadianceSettingsState build() {
    _refresh();
    return const RadianceSettingsState();
  }

  /// Fetches all settings in parallel and assigns a fresh state from the
  /// results. On a per-field fetch failure, falls back to the hardcoded
  /// default for that field. Each future is awaited into a named variable
  /// (positional-by-name, not positional-by-index) so adding another
  /// optional fetch later can't silently desync the read indices.
  Future<void> _refresh() async {
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
    state = RadianceSettingsState(
      blockAds: blockAds.fold((_) => defaults.blockAds, (v) => v),
      routingMode: routingRequests != _routingRequests
          ? state.routingMode
          : routing.fold(
              (_) => defaults.routingMode,
              (smart) => smart ? RoutingMode.smart : RoutingMode.full,
            ),
      telemetry: telemetry.fold((_) => defaults.telemetry, (v) => v),
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
    if (request == _routingRequests) _routingTarget = null;
    return result.fold(
      (err) {
        appLogger.error('setRoutingMode failed: ${err.error}');
        return left(err);
      },
      (_) {
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

  Future<void> setTelemetry(bool consent) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.updateTelemetryEvents(consent);
    if (!ref.mounted) return;
    result.fold(
      (err) => appLogger.error('updateTelemetryEvents failed: ${err.error}'),
      (_) => state = state.copyWith(telemetry: consent),
    );
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
