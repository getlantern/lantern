import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_locations_provider.g.dart';

/// Provides all available server locations from the config response.
/// Unlike availableServersProvider (which returns active outbounds),
/// this returns every location the user can select — including ones
/// without current routes. Used by the pro location picker.
@Riverpod(keepAlive: true)
class ServerLocationsNotifier extends _$ServerLocationsNotifier {
  @override
  Future<List<Location_>> build() async {
    final result = await ref.read(lanternServiceProvider).getServerLocations();
    return result.fold(
      (failure) {
        appLogger.error(
            'Error getting server locations: ${failure.localizedErrorMessage}');
        throw Exception('Failed to get server locations');
      },
      (locations) {
        return locations.map((loc) {
          final l = Location_.fromJson(loc as Map<String, dynamic>);
          // Generate a tag from city+country for location-based selection.
          // This tag is used by the UI to track selection state.
          if (l.tag.isEmpty) {
            l.tag = '${l.city}-${l.countryCode}'.toLowerCase().replaceAll(' ', '-');
          }
          return l;
        }).toList();
      },
    );
  }

  Future<void> refresh() async {
    final result = await ref.read(lanternServiceProvider).getServerLocations();
    result.fold(
      (failure) {
        appLogger.error(
            'Error refreshing server locations: ${failure.localizedErrorMessage}');
      },
      (locations) {
        state = AsyncValue.data(
          locations
              .map((loc) => Location_.fromJson(loc as Map<String, dynamic>))
              .toList(),
        );
      },
    );
  }
}
