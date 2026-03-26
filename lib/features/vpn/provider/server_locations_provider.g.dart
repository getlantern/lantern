// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_locations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a unified list of all server locations from radiance's AllLocations().
/// Each location includes active status and protocol info — radiance handles the
/// merge logic so the client doesn't need to juggle multiple data sources.

@ProviderFor(ServerLocationsNotifier)
final serverLocationsProvider = ServerLocationsNotifierProvider._();

/// Provides a unified list of all server locations from radiance's AllLocations().
/// Each location includes active status and protocol info — radiance handles the
/// merge logic so the client doesn't need to juggle multiple data sources.
final class ServerLocationsNotifierProvider
    extends $AsyncNotifierProvider<ServerLocationsNotifier, List<Location_>> {
  /// Provides a unified list of all server locations from radiance's AllLocations().
  /// Each location includes active status and protocol info — radiance handles the
  /// merge logic so the client doesn't need to juggle multiple data sources.
  ServerLocationsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverLocationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverLocationsNotifierHash();

  @$internal
  @override
  ServerLocationsNotifier create() => ServerLocationsNotifier();
}

String _$serverLocationsNotifierHash() =>
    r'edd93c18fb6438cf8b9e295bd2aa6e7eca12d9f5';

/// Provides a unified list of all server locations from radiance's AllLocations().
/// Each location includes active status and protocol info — radiance handles the
/// merge logic so the client doesn't need to juggle multiple data sources.

abstract class _$ServerLocationsNotifier
    extends $AsyncNotifier<List<Location_>> {
  FutureOr<List<Location_>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Location_>>, List<Location_>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Location_>>, List<Location_>>,
              AsyncValue<List<Location_>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
