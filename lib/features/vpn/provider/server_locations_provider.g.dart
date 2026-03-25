// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_locations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides all available server locations from the config response.
/// Unlike availableServersProvider (which returns active outbounds),
/// this returns every location the user can select — including ones
/// without current routes. Used by the pro location picker.

@ProviderFor(ServerLocationsNotifier)
final serverLocationsProvider = ServerLocationsNotifierProvider._();

/// Provides all available server locations from the config response.
/// Unlike availableServersProvider (which returns active outbounds),
/// this returns every location the user can select — including ones
/// without current routes. Used by the pro location picker.
final class ServerLocationsNotifierProvider
    extends $AsyncNotifierProvider<ServerLocationsNotifier, List<Location_>> {
  /// Provides all available server locations from the config response.
  /// Unlike availableServersProvider (which returns active outbounds),
  /// this returns every location the user can select — including ones
  /// without current routes. Used by the pro location picker.
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
    r'd9ea7a6cbd0fe7bbe2ea0e3213c685bd4cfc4931';

/// Provides all available server locations from the config response.
/// Unlike availableServersProvider (which returns active outbounds),
/// this returns every location the user can select — including ones
/// without current routes. Used by the pro location picker.

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
