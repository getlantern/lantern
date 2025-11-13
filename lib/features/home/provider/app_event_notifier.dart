import 'dart:async';

import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  /// Currently, it listens for 'config' events.
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
          break;
        default:
          break;
      }
    });
  }
}
