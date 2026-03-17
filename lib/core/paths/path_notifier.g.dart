// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'path_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PathNotifier)
final pathProvider = PathNotifierProvider._();

final class PathNotifierProvider
    extends $AsyncNotifierProvider<PathNotifier, PathManager> {
  PathNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pathProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pathNotifierHash();

  @$internal
  @override
  PathNotifier create() => PathNotifier();
}

String _$pathNotifierHash() => r'3d43afa1c79843ed2e254b440feeec016a956763';

abstract class _$PathNotifier extends $AsyncNotifier<PathManager> {
  FutureOr<PathManager> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PathManager>, PathManager>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PathManager>, PathManager>,
              AsyncValue<PathManager>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
