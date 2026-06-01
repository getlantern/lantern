import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'radiance_settings_providers.g.dart';

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
    final splitF = PlatformUtils.isIOS ? null : svc.isSplitTunnelingEnabled();
    // Peer-proxy probe runs on every platform with a handler wired up:
    // Windows + Linux via FFI, macOS + Android + iOS via MethodChannel.
    // Manual port forwarding works on any home WiFi where the user owns
    // the router, so mobile is included rather than desktop-only.
    final peerF = svc.isPeerProxyEnabled();

    final blockAds = await blockAdsF;
    final routing = await routingF;
    final telemetry = await telemetryF;
    final split = splitF == null ? null : await splitF;
    final peer = await peerF;
    if (!ref.mounted) return;

    const defaults = RadianceSettingsState();
    state = RadianceSettingsState(
      blockAds: blockAds.fold((_) => defaults.blockAds, (v) => v),
      routingMode: routing.fold(
        (_) => defaults.routingMode,
        (smart) => smart ? RoutingMode.smart : RoutingMode.full,
      ),
      telemetry: telemetry.fold((_) => defaults.telemetry, (v) => v),
      splitTunneling: split == null
          ? defaults.splitTunneling
          : split.fold((_) => defaults.splitTunneling, (v) => v),
      peerProxy: peer.fold((_) => defaults.peerProxy, (v) => v),
    );
  }

  Future<void> setBlockAds(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setBlockAdsEnabled(value);
    if (!ref.mounted) return;
    result.fold(
      (err) => appLogger.error('setBlockAdsEnabled failed: ${err.error}'),
      (_) => state = state.copyWith(blockAds: value),
    );
  }

  Future<Either<Failure, Unit>> setRoutingMode(RoutingMode mode) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setRoutingMode(mode == RoutingMode.smart);
    if (!ref.mounted) return right(unit);
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

  Future<void> setSplitTunneling(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setSplitTunnelingEnabled(value);
    if (!ref.mounted) return;
    result.fold(
      (err) => appLogger.error('setSplitTunnelingEnabled failed: ${err.error}'),
      (_) => state = state.copyWith(splitTunneling: value),
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
  /// failure — share_my_connection.dart's _start depends on it to
  /// revert UI state if the setting flip fails before peer.Client
  /// emits its own phase=error StatusEvent. Internal logging still
  /// happens on failure for fire-and-forget call sites.
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
