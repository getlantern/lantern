// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manage_server_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ManageServerNotifier)
const manageServerProvider = ManageServerNotifierProvider._();

final class ManageServerNotifierProvider
    extends $AsyncNotifierProvider<ManageServerNotifier, List<PrivateServer>> {
  const ManageServerNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'manageServerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$manageServerNotifierHash();

  @$internal
  @override
  ManageServerNotifier create() => ManageServerNotifier();
}

String _$manageServerNotifierHash() =>
    r'848b1e3c8c1847075d102f0287c4adfd4c545a30';

abstract class _$ManageServerNotifier
    extends $AsyncNotifier<List<PrivateServer>> {
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
