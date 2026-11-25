// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_tray_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SystemTrayNotifier)
final systemTrayProvider = SystemTrayNotifierProvider._();

final class SystemTrayNotifierProvider
    extends $AsyncNotifierProvider<SystemTrayNotifier, void> {
  SystemTrayNotifierProvider._()
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
    r'394c87a668f4bdb8acacbc0ff7306fa95de6dabd';

abstract class _$SystemTrayNotifier extends $AsyncNotifier<void> {
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
