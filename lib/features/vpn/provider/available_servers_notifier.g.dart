// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'available_servers_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AvailableServersNotifier)
const availableServersProvider = AvailableServersNotifierProvider._();

final class AvailableServersNotifierProvider
    extends $AsyncNotifierProvider<AvailableServersNotifier, AvailableServers> {
  const AvailableServersNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'availableServersProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$availableServersNotifierHash();

  @$internal
  @override
  AvailableServersNotifier create() => AvailableServersNotifier();
}

String _$availableServersNotifierHash() =>
    r'dadbf7c0688a380dfd6611d342c47e4f3b0b2b8e';

abstract class _$AvailableServersNotifier
    extends $AsyncNotifier<AvailableServers> {
  FutureOr<AvailableServers> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<AvailableServers>, AvailableServers>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<AvailableServers>, AvailableServers>,
        AsyncValue<AvailableServers>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
