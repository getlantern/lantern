// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'available_servers_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AvailableServersNotifier)
final availableServersProvider = AvailableServersNotifierProvider._();

final class AvailableServersNotifierProvider
    extends $AsyncNotifierProvider<AvailableServersNotifier, AvailableServers> {
  AvailableServersNotifierProvider._()
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
    r'65d0c88c1e4a4ff612231d7c3d041f7d3cee9282';

abstract class _$AvailableServersNotifier
    extends $AsyncNotifier<AvailableServers> {
  FutureOr<AvailableServers> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AvailableServers>, AvailableServers>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AvailableServers>, AvailableServers>,
              AsyncValue<AvailableServers>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
