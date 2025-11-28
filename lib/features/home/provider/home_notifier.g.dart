// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeNotifier)
const homeProvider = HomeNotifierProvider._();

final class HomeNotifierProvider
    extends $AsyncNotifierProvider<HomeNotifier, UserResponse> {
  const HomeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'homeProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeNotifierHash();

  @$internal
  @override
  HomeNotifier create() => HomeNotifier();
}

String _$homeNotifierHash() => r'32700b1574dd38df39f63c4bdd923212820356cf';

abstract class _$HomeNotifier extends $AsyncNotifier<UserResponse> {
  FutureOr<UserResponse> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<UserResponse>, UserResponse>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<UserResponse>, UserResponse>,
        AsyncValue<UserResponse>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
