// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_servers_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrivateServers)
const privateServersProvider = PrivateServersProvider._();

final class PrivateServersProvider
    extends $AsyncNotifierProvider<PrivateServers, List<PrivateServer>> {
  const PrivateServersProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'privateServersProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$privateServersHash();

  @$internal
  @override
  PrivateServers create() => PrivateServers();
}

String _$privateServersHash() => r'3d0440980435f7fdc6d5b405fc85dbb514a71084';

abstract class _$PrivateServers extends $AsyncNotifier<List<PrivateServer>> {
  FutureOr<List<PrivateServer>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<PrivateServer>>, List<PrivateServer>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<PrivateServer>>, List<PrivateServer>>,
        AsyncValue<List<PrivateServer>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
