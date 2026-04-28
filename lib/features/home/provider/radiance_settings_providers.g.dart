// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'radiance_settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds radiance-backed VPN preferences in memory.
///
/// The notifier returns safe defaults synchronously from [build], then kicks
/// off a single background refresh that fetches the real values from the
/// native layer and updates state. Mutations update state in place on success,
/// avoiding an extra native round-trip just to re-read what we just wrote.

@ProviderFor(RadianceSettings)
final radianceSettingsProvider = RadianceSettingsProvider._();

/// Holds radiance-backed VPN preferences in memory.
///
/// The notifier returns safe defaults synchronously from [build], then kicks
/// off a single background refresh that fetches the real values from the
/// native layer and updates state. Mutations update state in place on success,
/// avoiding an extra native round-trip just to re-read what we just wrote.
final class RadianceSettingsProvider
    extends $NotifierProvider<RadianceSettings, RadianceSettingsState> {
  /// Holds radiance-backed VPN preferences in memory.
  ///
  /// The notifier returns safe defaults synchronously from [build], then kicks
  /// off a single background refresh that fetches the real values from the
  /// native layer and updates state. Mutations update state in place on success,
  /// avoiding an extra native round-trip just to re-read what we just wrote.
  RadianceSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'radianceSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$radianceSettingsHash();

  @$internal
  @override
  RadianceSettings create() => RadianceSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RadianceSettingsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RadianceSettingsState>(value),
    );
  }
}

String _$radianceSettingsHash() => r'a194e30ee94b62d3b20a2ab03a6878e1aa045516';

/// Holds radiance-backed VPN preferences in memory.
///
/// The notifier returns safe defaults synchronously from [build], then kicks
/// off a single background refresh that fetches the real values from the
/// native layer and updates state. Mutations update state in place on success,
/// avoiding an extra native round-trip just to re-read what we just wrote.

abstract class _$RadianceSettings extends $Notifier<RadianceSettingsState> {
  RadianceSettingsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RadianceSettingsState, RadianceSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RadianceSettingsState, RadianceSettingsState>,
              RadianceSettingsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

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
