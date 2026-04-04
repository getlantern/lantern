// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'radiance_settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches ad-block status on demand from radiance.

@ProviderFor(blockAdsEnabled)
final blockAdsEnabledProvider = BlockAdsEnabledProvider._();

/// Fetches ad-block status on demand from radiance.

final class BlockAdsEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Fetches ad-block status on demand from radiance.
  BlockAdsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blockAdsEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blockAdsEnabledHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return blockAdsEnabled(ref);
  }
}

String _$blockAdsEnabledHash() => r'4aaa738b21dea4c02e4505b7a4925c71126ebb8f';

/// Fetches routing mode on demand from radiance.

@ProviderFor(routingMode)
final routingModeProvider = RoutingModeProvider._();

/// Fetches routing mode on demand from radiance.

final class RoutingModeProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoutingMode>,
          RoutingMode,
          FutureOr<RoutingMode>
        >
    with $FutureModifier<RoutingMode>, $FutureProvider<RoutingMode> {
  /// Fetches routing mode on demand from radiance.
  RoutingModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routingModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routingModeHash();

  @$internal
  @override
  $FutureProviderElement<RoutingMode> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RoutingMode> create(Ref ref) {
    return routingMode(ref);
  }
}

String _$routingModeHash() => r'3eb46904af8d2a86af2d585807f980ca7ed67634';

/// Fetches split-tunneling enabled status on demand from radiance.

@ProviderFor(splitTunnelingEnabled)
final splitTunnelingEnabledProvider = SplitTunnelingEnabledProvider._();

/// Fetches split-tunneling enabled status on demand from radiance.

final class SplitTunnelingEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Fetches split-tunneling enabled status on demand from radiance.
  SplitTunnelingEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'splitTunnelingEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$splitTunnelingEnabledHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return splitTunnelingEnabled(ref);
  }
}

String _$splitTunnelingEnabledHash() =>
    r'8d3e75582214e10b4266003963a69fdbef91c381';

/// Fetches telemetry consent on demand from radiance.

@ProviderFor(telemetryConsent)
final telemetryConsentProvider = TelemetryConsentProvider._();

/// Fetches telemetry consent on demand from radiance.

final class TelemetryConsentProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Fetches telemetry consent on demand from radiance.
  TelemetryConsentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'telemetryConsentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$telemetryConsentHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return telemetryConsent(ref);
  }
}

String _$telemetryConsentHash() => r'314d581209fa868fc9a66dfe15eade98c66abd42';

/// Fetches whether user logged in via OAuth from radiance.

@ProviderFor(isOAuthLogin)
final isOAuthLoginProvider = IsOAuthLoginProvider._();

/// Fetches whether user logged in via OAuth from radiance.

final class IsOAuthLoginProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Fetches whether user logged in via OAuth from radiance.
  IsOAuthLoginProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isOAuthLoginProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isOAuthLoginHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return isOAuthLogin(ref);
  }
}

String _$isOAuthLoginHash() => r'7711849921b77b27fab46efaeeccc33b0ae56811';

/// Fetches OAuth provider name from radiance.

@ProviderFor(oAuthProvider)
final oAuthProviderProvider = OAuthProviderProvider._();

/// Fetches OAuth provider name from radiance.

final class OAuthProviderProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Fetches OAuth provider name from radiance.
  OAuthProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oAuthProviderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oAuthProviderHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return oAuthProvider(ref);
  }
}

String _$oAuthProviderHash() => r'9d243b3a7155010f71c948211aa732c579fc63e1';

/// Whether the user is an SSO user (OAuth login with a provider set).

@ProviderFor(isSSOUser)
final isSSOUserProvider = IsSSOUserProvider._();

/// Whether the user is an SSO user (OAuth login with a provider set).

final class IsSSOUserProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the user is an SSO user (OAuth login with a provider set).
  IsSSOUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isSSOUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isSSOUserHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return isSSOUser(ref);
  }
}

String _$isSSOUserHash() => r'07a9fd3a10783d8b12a5c837224b732f7432f46c';

/// Controller for mutating ad-block setting via radiance.

@ProviderFor(BlockAdsController)
final blockAdsControllerProvider = BlockAdsControllerProvider._();

/// Controller for mutating ad-block setting via radiance.
final class BlockAdsControllerProvider
    extends $AsyncNotifierProvider<BlockAdsController, void> {
  /// Controller for mutating ad-block setting via radiance.
  BlockAdsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blockAdsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blockAdsControllerHash();

  @$internal
  @override
  BlockAdsController create() => BlockAdsController();
}

String _$blockAdsControllerHash() =>
    r'9fc5bd1db85364eb53b670ed9856ca924af28562';

/// Controller for mutating ad-block setting via radiance.

abstract class _$BlockAdsController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Controller for mutating routing mode via radiance.

@ProviderFor(RoutingModeController)
final routingModeControllerProvider = RoutingModeControllerProvider._();

/// Controller for mutating routing mode via radiance.
final class RoutingModeControllerProvider
    extends $AsyncNotifierProvider<RoutingModeController, void> {
  /// Controller for mutating routing mode via radiance.
  RoutingModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routingModeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routingModeControllerHash();

  @$internal
  @override
  RoutingModeController create() => RoutingModeController();
}

String _$routingModeControllerHash() =>
    r'480fd991ad95a8392afc3a61561314fe9343421d';

/// Controller for mutating routing mode via radiance.

abstract class _$RoutingModeController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Controller for mutating split-tunneling enabled via radiance.

@ProviderFor(SplitTunnelingController)
final splitTunnelingControllerProvider = SplitTunnelingControllerProvider._();

/// Controller for mutating split-tunneling enabled via radiance.
final class SplitTunnelingControllerProvider
    extends $AsyncNotifierProvider<SplitTunnelingController, void> {
  /// Controller for mutating split-tunneling enabled via radiance.
  SplitTunnelingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'splitTunnelingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$splitTunnelingControllerHash();

  @$internal
  @override
  SplitTunnelingController create() => SplitTunnelingController();
}

String _$splitTunnelingControllerHash() =>
    r'1ff35c678ade31eef6081e0b6a32861afb987c14';

/// Controller for mutating split-tunneling enabled via radiance.

abstract class _$SplitTunnelingController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Controller for mutating telemetry consent via radiance.

@ProviderFor(TelemetryController)
final telemetryControllerProvider = TelemetryControllerProvider._();

/// Controller for mutating telemetry consent via radiance.
final class TelemetryControllerProvider
    extends $AsyncNotifierProvider<TelemetryController, void> {
  /// Controller for mutating telemetry consent via radiance.
  TelemetryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'telemetryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$telemetryControllerHash();

  @$internal
  @override
  TelemetryController create() => TelemetryController();
}

String _$telemetryControllerHash() =>
    r'7ef9bb82d16c321a3363d286e038d7f58a43846a';

/// Controller for mutating telemetry consent via radiance.

abstract class _$TelemetryController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
