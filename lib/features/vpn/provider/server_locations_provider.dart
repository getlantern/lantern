import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_locations_provider.g.dart';

/// Provides a unified list of all server locations from radiance's AllLocations().
/// Each location includes active status and protocol info — radiance handles the
/// merge logic so the client doesn't need to juggle multiple data sources.
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
      (locations) => _parseLocations(locations),
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
        state = AsyncValue.data(_parseLocations(locations));
      },
    );
  }

  List<Location_> _parseLocations(List<dynamic> locations) {
    return locations.map((loc) {
      final map = loc as Map<String, dynamic>;
      final l = Location_.fromJson(map);
      // Radiance's AllLocations() provides tag and protocol directly.
      // Use tag from response if present, otherwise generate from city+country.
      if (l.tag.isEmpty) {
        l.tag = '${l.city}-${l.countryCode}'.toLowerCase().replaceAll(' ', '-');
      }
      // Protocol comes from the active outbound type (e.g., "samizdat", "hysteria2").
      // Empty if the location has no active routes.
      final protocol = map['protocol'] as String? ?? '';
      if (protocol.isNotEmpty) {
        l.protocol = protocol;
      }
      return l;
    }).toList();
  }
}
