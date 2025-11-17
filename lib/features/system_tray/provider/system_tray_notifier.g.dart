// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_tray_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SystemTrayNotifier)
const systemTrayProvider = SystemTrayNotifierProvider._();

final class SystemTrayNotifierProvider
    extends $AsyncNotifierProvider<SystemTrayNotifier, void> {
  const SystemTrayNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'systemTrayProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$systemTrayNotifierHash();

  @$internal
  @override
  SystemTrayNotifier create() => SystemTrayNotifier();
}

String _$systemTrayNotifierHash() =>
    r'53c175897ac2cb352b3ee8a669aff2a4b87d6e7c';

abstract class _$SystemTrayNotifier extends $AsyncNotifier<void> {
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
