// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_server_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrivateServerNotifier)
const privateServerProvider = PrivateServerNotifierProvider._();

final class PrivateServerNotifierProvider
    extends $NotifierProvider<PrivateServerNotifier, PrivateServerStatus> {
  const PrivateServerNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'privateServerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$privateServerNotifierHash();

  @$internal
  @override
  PrivateServerNotifier create() => PrivateServerNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivateServerStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivateServerStatus>(value),
    );
  }
}

String _$privateServerNotifierHash() =>
    r'ea0b54563620c6b316db76f4d51211f27a6a62d3';

abstract class _$PrivateServerNotifier extends $Notifier<PrivateServerStatus> {
  PrivateServerStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PrivateServerStatus, PrivateServerStatus>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<PrivateServerStatus, PrivateServerStatus>,
        PrivateServerStatus,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
