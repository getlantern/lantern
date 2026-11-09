// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_proxies_intro.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where Action Mode is offered: where Home shows its tab.

@ProviderFor(actionModeOffered)
final actionModeOfferedProvider = ActionModeOfferedProvider._();

/// Where Action Mode is offered: where Home shows its tab.

final class ActionModeOfferedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Where Action Mode is offered: where Home shows its tab.
  ActionModeOfferedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actionModeOfferedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actionModeOfferedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return actionModeOffered(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$actionModeOfferedHash() => r'46bd01e174d2199189456855a983a93b41da29d2';

@ProviderFor(personalProxiesIntroPages)
final personalProxiesIntroPagesProvider = PersonalProxiesIntroPagesProvider._();

final class PersonalProxiesIntroPagesProvider
    extends
        $FunctionalProvider<
          PersonalProxiesIntroPages,
          PersonalProxiesIntroPages,
          PersonalProxiesIntroPages
        >
    with $Provider<PersonalProxiesIntroPages> {
  PersonalProxiesIntroPagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalProxiesIntroPagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalProxiesIntroPagesHash();

  @$internal
  @override
  $ProviderElement<PersonalProxiesIntroPages> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalProxiesIntroPages create(Ref ref) {
    return personalProxiesIntroPages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalProxiesIntroPages value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalProxiesIntroPages>(value),
    );
  }
}

String _$personalProxiesIntroPagesHash() =>
    r'64282e632f0b0a03f56e7acb22705b9fe2123c0f';
