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
    extends $NotifierProvider<ManageServerNotifier, void> {
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
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$manageServerNotifierHash() =>
    r'257f97ae48e8976ae7be8571c1d81be5604806b9';

abstract class _$ManageServerNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<void, void>, void, Object?, Object?>;
    element.handleValue(ref, null);
  }
}
