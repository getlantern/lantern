// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'helpers_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether this build and the server let this device use helper invites.

@ProviderFor(helperInvitesAvailable)
final helperInvitesAvailableProvider = HelperInvitesAvailableProvider._();

/// Whether this build and the server let this device use helper invites.

final class HelperInvitesAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this build and the server let this device use helper invites.
  HelperInvitesAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helperInvitesAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helperInvitesAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return helperInvitesAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$helperInvitesAvailableHash() =>
    r'28b6defb614c556b2fadebc03865e801586b6872';

/// Whether settings offer "Get help from a friend": while helper invites are
/// available, and after the flag goes off while this device still has
/// helpers or invites to manage, or may have them: it used helper invites
/// and no view has loaded yet. Reads only the notifier's state and the used
/// mark in local storage, never the keystore, so a device that never used
/// them stays hidden.

@ProviderFor(helperEntryVisible)
final helperEntryVisibleProvider = HelperEntryVisibleProvider._();

/// Whether settings offer "Get help from a friend": while helper invites are
/// available, and after the flag goes off while this device still has
/// helpers or invites to manage, or may have them: it used helper invites
/// and no view has loaded yet. Reads only the notifier's state and the used
/// mark in local storage, never the keystore, so a device that never used
/// them stays hidden.

final class HelperEntryVisibleProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether settings offer "Get help from a friend": while helper invites are
  /// available, and after the flag goes off while this device still has
  /// helpers or invites to manage, or may have them: it used helper invites
  /// and no view has loaded yet. Reads only the notifier's state and the used
  /// mark in local storage, never the keystore, so a device that never used
  /// them stays hidden.
  HelperEntryVisibleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helperEntryVisibleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helperEntryVisibleHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return helperEntryVisible(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$helperEntryVisibleHash() =>
    r'583159a4d2587bc65da4bdac79291d1494bbdca4';

/// The app's side of helper invites. Every operation goes to lantern-core's
/// engine through [LanternService.helperCall]. Links, names and codes are
/// never logged.

@ProviderFor(HelpersNotifier)
final helpersProvider = HelpersNotifierProvider._();

/// The app's side of helper invites. Every operation goes to lantern-core's
/// engine through [LanternService.helperCall]. Links, names and codes are
/// never logged.
final class HelpersNotifierProvider
    extends $NotifierProvider<HelpersNotifier, HelpersState> {
  /// The app's side of helper invites. Every operation goes to lantern-core's
  /// engine through [LanternService.helperCall]. Links, names and codes are
  /// never logged.
  HelpersNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helpersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helpersNotifierHash();

  @$internal
  @override
  HelpersNotifier create() => HelpersNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HelpersState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HelpersState>(value),
    );
  }
}

String _$helpersNotifierHash() => r'0c5eb5ff0396001b200e7f5a0878fb16e8b616e4';

/// The app's side of helper invites. Every operation goes to lantern-core's
/// engine through [LanternService.helperCall]. Links, names and codes are
/// never logged.

abstract class _$HelpersNotifier extends $Notifier<HelpersState> {
  HelpersState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<HelpersState, HelpersState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HelpersState, HelpersState>,
              HelpersState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
