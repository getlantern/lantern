// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_location_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServerLocationNotifier)
final serverLocationProvider = ServerLocationNotifierProvider._();

final class ServerLocationNotifierProvider
    extends $NotifierProvider<ServerLocationNotifier, ServerLocation> {
  ServerLocationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverLocationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverLocationNotifierHash();

  @$internal
  @override
  ServerLocationNotifier create() => ServerLocationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerLocation value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerLocation>(value),
    );
  }
}

String _$serverLocationNotifierHash() =>
    r'c103e3e1a200243b99afbcc04891ec5c157ad840';

abstract class _$ServerLocationNotifier extends $Notifier<ServerLocation> {
  ServerLocation build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ServerLocation, ServerLocation>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServerLocation, ServerLocation>,
              ServerLocation,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
