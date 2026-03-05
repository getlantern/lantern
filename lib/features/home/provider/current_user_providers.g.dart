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
