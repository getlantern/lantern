// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_location_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServerLocationNotifier)
const serverLocationProvider = ServerLocationNotifierProvider._();

final class ServerLocationNotifierProvider
    extends $NotifierProvider<ServerLocationNotifier, ServerLocationEntity> {
  const ServerLocationNotifierProvider._()
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
  Override overrideWithValue(ServerLocationEntity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerLocationEntity>(value),
    );
  }
}

String _$serverLocationNotifierHash() =>
    r'28a95cf3f636ad0628e787401e1abd4479770570';

abstract class _$ServerLocationNotifier
    extends $Notifier<ServerLocationEntity> {
  ServerLocationEntity build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ServerLocationEntity, ServerLocationEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ServerLocationEntity, ServerLocationEntity>,
        ServerLocationEntity,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
