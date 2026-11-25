// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WindowNotifier)
final windowProvider = WindowNotifierProvider._();

final class WindowNotifierProvider
    extends $AsyncNotifierProvider<WindowNotifier, void> {
  WindowNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowNotifierHash();

  @$internal
  @override
  WindowNotifier create() => WindowNotifier();
}

String _$windowNotifierHash() => r'b4bfce3f215ed716c5f27da010e289325a01b618';

abstract class _$WindowNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
