// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WindowNotifier)
const windowProvider = WindowNotifierProvider._();

final class WindowNotifierProvider
    extends $AsyncNotifierProvider<WindowNotifier, void> {
  const WindowNotifierProvider._()
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

String _$windowNotifierHash() => r'afb3f1e44514d21c5562eeb6bcaa7d619d0f1b90';

abstract class _$WindowNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<void>, void>,
        AsyncValue<void>,
        Object?,
        Object?>;
    element.handleValue(ref, null);
  }
}
