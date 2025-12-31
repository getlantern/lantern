import 'dart:async';
import 'dart:convert';

import 'package:i18n_extension/default.i18n.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/entity/server_location_entity.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/available_servers.dart';

part 'app_event_notifier.g.dart';

/// Listens for application-wide events and triggers corresponding actions.
/// This can be used for all listening to events that go sends and handling them
/// in one place.
@Riverpod(keepAlive: true)
class AppEventNotifier extends _$AppEventNotifier {
  StreamSubscription? _appEventSub;

  @override
  Future<void> build() async {
    watchAppEvents();
    ref.onDispose(() {
      appLogger
          .debug('Disposing AppEventNotifier and cancelling subscriptions.');
      _appEventSub?.cancel();
    });
  }

  /// Watches for application events and triggers appropriate actions.
  /// Currently, it listens for 'config' and server-location events.
  void watchAppEvents() {
    appLogger.debug('Setting up app event listener...');
    _appEventSub =
        ref.read(lanternServiceProvider).watchAppEvents().listen((event) {
      final eventType = event.eventType;
      switch (eventType) {
        case 'config':
          appLogger.debug('Received new config event.');
          ref
              .read(availableServersProvider.notifier)
              .forceFetchAvailableServers();

          /// this will also refresh user data if needed
          ref.read(homeProvider.notifier).fetchUserDataIfNeeded();
          break;
        case 'server-location':
          try {
            appLogger
                .debug('Received server-location event, updating location.');
            final autoLocation = Server.fromJson(jsonDecode(event.message));
            final countryName = autoLocation.location!.country;
            final cityName = autoLocation.location!.city;
            final autoServer = ServerLocationEntity(
              serverType: ServerLocationType.auto.name,
              serverName: ''.i18n,
              autoSelect: true,
              displayName: '',
              protocol: '',
              city: autoLocation.location!.city,
              autoLocationParam: AutoLocationEntity(
                countryCode: autoLocation.location!.countryCode,
                country: countryName,
                displayName: '$countryName - $cityName',
                tag: autoLocation.tag,
              ),
            );
            ref
                .read(serverLocationProvider.notifier)
                .updateServerLocation(autoServer);
          } catch (e) {
            appLogger.error('Error parsing server-location event: $e');
          }
          break;
        default:
          break;
      }
    });
  }
}
