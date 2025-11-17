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

String _$windowNotifierHash() => r'786fcb399f0f98df79f531ec9caacb46284ca5ac';

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
