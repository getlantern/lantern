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
    extends $NotifierProvider<ManageServerNotifier, List<PrivateServerEntity>> {
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

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PrivateServerEntity> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PrivateServerEntity>>(value),
    );
  }
}

String _$manageServerNotifierHash() =>
    r'b87b605c74a1ee5df52609df98dc26d78115e8c5';

abstract class _$ManageServerNotifier
    extends $Notifier<List<PrivateServerEntity>> {
  List<PrivateServerEntity> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<List<PrivateServerEntity>, List<PrivateServerEntity>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<PrivateServerEntity>, List<PrivateServerEntity>>,
        List<PrivateServerEntity>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
