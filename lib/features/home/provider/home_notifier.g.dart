// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeNotifier)
final homeProvider = HomeNotifierProvider._();

final class HomeNotifierProvider
    extends $AsyncNotifierProvider<HomeNotifier, UserResponseModel> {
  HomeNotifierProvider._()
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

String _$homeNotifierHash() => r'dfb0929bbbb1cefa194cb98c46e637e72f5697f7';

abstract class _$HomeNotifier extends $AsyncNotifier<UserResponseModel> {
  FutureOr<UserResponseModel> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<UserResponseModel>, UserResponseModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserResponseModel>, UserResponseModel>,
              AsyncValue<UserResponseModel>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
