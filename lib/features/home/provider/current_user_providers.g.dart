// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_user_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(currentUser)
const currentUserProvider = CurrentUserProvider._();

final class CurrentUserProvider
    extends $FunctionalProvider<UserResponse?, UserResponse?, UserResponse?>
    with $Provider<UserResponse?> {
  const CurrentUserProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentUserProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $ProviderElement<UserResponse?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserResponse? create(Ref ref) {
    return currentUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserResponse? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserResponse?>(value),
    );
  }
}

String _$currentUserHash() => r'f78267102cb4e70ab6a5d55e1c02a2ae32d71915';

@ProviderFor(isUserProFromCore)
const isUserProFromCoreProvider = IsUserProFromCoreProvider._();

final class IsUserProFromCoreProvider
    extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  const IsUserProFromCoreProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isUserProFromCoreProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isUserProFromCoreHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isUserProFromCore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isUserProFromCoreHash() => r'9f84babf8a85f3d1df327e94d3a53fd1b5561159';

@ProviderFor(userEmailFromCore)
const userEmailFromCoreProvider = UserEmailFromCoreProvider._();

final class UserEmailFromCoreProvider
    extends $FunctionalProvider<String, String, String> with $Provider<String> {
  const UserEmailFromCoreProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'userEmailFromCoreProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$userEmailFromCoreHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return userEmailFromCore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$userEmailFromCoreHash() => r'c5bf6fd10983336a7f025e89b5a1f6ce5dec47d0';
