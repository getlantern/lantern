import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'radiance_settings_providers.g.dart';

/// Fetches ad-block status on demand from radiance.
@riverpod
Future<bool> blockAdsEnabled(Ref ref) async {
  final svc = ref.read(lanternServiceProvider);
  final result = await svc.isBlockAdsEnabled();
  return result.fold((_) => false, (v) => v);
}

/// Fetches routing mode on demand from radiance.
@riverpod
Future<RoutingMode> routingMode(Ref ref) async {
  final svc = ref.read(lanternServiceProvider);
  final result = await svc.isSmartRoutingEnabled();
  return result.fold(
    (_) => RoutingMode.full,
    (smart) => smart ? RoutingMode.smart : RoutingMode.full,
  );
}

/// Fetches split-tunneling enabled status on demand from radiance.
@riverpod
Future<bool> splitTunnelingEnabled(Ref ref) async {
  final svc = ref.read(lanternServiceProvider);
  final result = await svc.isSplitTunnelingEnabled();
  return result.fold((_) => false, (v) => v);
}

/// Fetches telemetry consent on demand from radiance.
@riverpod
Future<bool> telemetryConsent(Ref ref) async {
  final svc = ref.read(lanternServiceProvider);
  final result = await svc.isTelemetryEnabled();
  return result.fold((_) => false, (v) => v);
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

/// Controller for mutating ad-block setting via radiance.
@riverpod
class BlockAdsController extends _$BlockAdsController {
  @override
  FutureOr<void> build() {}

  Future<void> toggle(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setBlockAdsEnabled(value);
    if (!ref.mounted) return;
    result.fold(
      (err) => appLogger.error('setBlockAdsEnabled failed: ${err.error}'),
      (_) => ref.invalidate(blockAdsEnabledProvider),
    );
  }
}

/// Controller for mutating routing mode via radiance.
@riverpod
class RoutingModeController extends _$RoutingModeController {
  @override
  FutureOr<void> build() {}

  Future<Either<Failure, Unit>> set(RoutingMode mode) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setRoutingMode(mode == RoutingMode.smart);
    if (!ref.mounted) return right(unit);
    return result.fold(
      (err) {
        appLogger.error('setRoutingMode failed: ${err.error}');
        return left(err);
      },
      (_) {
        ref.invalidate(routingModeProvider);
        return right(unit);
      },
    );
  }
}

/// Controller for mutating split-tunneling enabled via radiance.
@riverpod
class SplitTunnelingController extends _$SplitTunnelingController {
  @override
  FutureOr<void> build() {}

  Future<void> toggle(bool value) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.setSplitTunnelingEnabled(value);
    if (!ref.mounted) return;
    result.fold(
      (err) =>
          appLogger.error('setSplitTunnelingEnabled failed: ${err.error}'),
      (_) => ref.invalidate(splitTunnelingEnabledProvider),
    );
  }
}

/// Controller for mutating telemetry consent via radiance.
@riverpod
class TelemetryController extends _$TelemetryController {
  @override
  FutureOr<void> build() {}

  Future<void> setConsent(bool consent) async {
    final svc = ref.read(lanternServiceProvider);
    final result = await svc.updateTelemetryEvents(consent);
    if (!ref.mounted) return;
    result.fold(
      (err) => appLogger.error('updateTelemetryEvents failed: ${err.error}'),
      (_) => ref.invalidate(telemetryConsentProvider),
    );
  }
}
