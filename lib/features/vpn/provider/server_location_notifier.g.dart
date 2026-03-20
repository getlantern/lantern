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
    extends $AsyncNotifierProvider<ServerLocationNotifier, ServerLocation> {
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
}

String _$serverLocationNotifierHash() =>
    r'9b7c13306682f80e6ce31eea5a9f9a5e74baedbc';

abstract class _$ServerLocationNotifier extends $AsyncNotifier<ServerLocation> {
  FutureOr<ServerLocation> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ServerLocation>, ServerLocation>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ServerLocation>, ServerLocation>,
              AsyncValue<ServerLocation>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
