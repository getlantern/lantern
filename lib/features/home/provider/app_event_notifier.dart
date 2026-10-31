import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/core/extensions/context.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/vpn/personal_proxies_section.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/available_servers.dart';
import 'data_cap_info_provider.dart' show dataCapInfoProvider;

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
      appLogger.debug(
        'Disposing AppEventNotifier and cancelling subscriptions.',
      );
      _appEventSub?.cancel();
    });
  }

  /// Event types that arrive continuously rather than occasionally: one per
  /// peer connection, and a data-cap poll every few seconds. Logging a line
  /// each made them 75% of a 297 MB flutter.log, which is what pushed issue
  /// reports past their attachment budget so users could not send logs at all.
  /// Per-event diagnostics are available at the opt-in trace level.
  static const _highVolumeEvents = {'peer-connection', 'data-cap-event'};

  /// Shows a message to the user. Tests replace it.
  @visibleForTesting
  static void Function(String message) showMessage = _showSnackBar;

  static void _showSnackBar(String message) {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    context.showSnackBar(message);
  }

  /// radiance switched the friend selected on their own, who has no route
  /// left, to the personal proxies group or to auto: tells the user, by the
  /// friend's name, and reads the selection again. Neither the tag nor the
  /// name is logged.
  Future<void> _personalProxyFellBack(String message) async {
    final String tag;
    final String fallback;
    try {
      final j = jsonDecode(message) as Map<String, dynamic>;
      tag = j['tag'] as String;
      fallback = j['fallback'] as String;
    } catch (_) {
      appLogger.error('Error parsing personal-proxy-fallback event');
      return;
    }
    final text = personalProxyFallbackMessage(
      ref.read(helpersProvider).view,
      tag,
      fallback,
    );
    if (text == null) return;
    showMessage(text);
    unawaited(ref.read(serverLocationProvider.notifier).syncSelection());
  }

  /// Watches for application events and triggers appropriate actions.
  /// Currently, it listens for 'config' and server-location events.
  void watchAppEvents() {
    appLogger.debug('Setting up app event listener...');
    _appEventSub = ref.read(lanternServiceProvider).watchAppEvents().listen((
      event,
    ) {
      final eventType = event.eventType;
      if (_highVolumeEvents.contains(eventType)) {
        appLogger.trace(() => 'Received app event of type: $eventType');
      } else {
        appLogger.debug('Received app event of type: $eventType');
      }
      switch (eventType) {
        case 'config':
          ref
              .read(availableServersProvider.notifier)
              .forceFetchAvailableServers();

          break;
        case 'server-location':
          // The selected server event is also our current Lantern-only signal
          // that Smart Location probe data may have changed.
          unawaited(
            ref
                .read(availableServersProvider.notifier)
                .forceFetchAvailableServers(),
          );
          // Only consume this event when the user is actually in auto mode.
          // Otherwise (custom server selected) ignore it — applying it would
          // silently flip the user's selection back to Smart Location on
          // routing-mode changes or any other tunnel rebuild.

          final currentLocation = ref.read(serverLocationProvider);
          if (currentLocation.serverType != ServerLocationType.auto.name) {
            break;
          }
          try {
            final autoServer = ServerLocation.autoSelected(
              Server.fromJson(jsonDecode(event.message)),
            );
            ref
                .read(serverLocationProvider.notifier)
                .updateServerLocation(autoServer);
          } catch (e) {
            appLogger.error('Error parsing server-location event: $e');
          }
          break;
        case 'country-code':
          ref.read(countryCodeProvider.notifier).update(event.message);
          break;
        case 'helper-live':
          // Carries nothing: the helper view holds the friends' status.
          unawaited(ref.read(helpersProvider.notifier).liveChanged());
          break;
        case 'selection-changed':
          // radiance saved a selection: show what it saved. Events can
          // repeat; each is only a prompt to read, and the newest read wins.
          unawaited(ref.read(serverLocationProvider.notifier).syncSelection());
          break;
        case 'personal-proxy-fallback':
          unawaited(_personalProxyFellBack(event.message));
          break;
        case 'user-data':
          // Go refreshed user data from the server; re-read the cache.
          unawaited(ref.read(homeProvider.notifier).reloadUserData());
          break;
        case 'data-cap-event':
          try {
            final data = event.message;
            final dataCapInfo = DataCapUsageResponse.fromJson(jsonDecode(data));
            ref
                .read(dataCapInfoProvider.notifier)
                .updateDataCapInfo(dataCapInfo);
          } catch (e) {
            appLogger.error('Error parsing data-cap-event: $e');
          }
          break;
        default:
          break;
      }
    });
    unawaited(_readStateOnListen());
  }

  /// How long the first read waits for the core to be ready.
  @visibleForTesting
  static Duration coreWait = const Duration(seconds: 30);

  /// Events sent before this listener existed never reach it: radiance
  /// replays its selection-saved event to the core, not to a late app
  /// listener. So the state those events prompt is read once here, when the
  /// core is ready, and never depends on catching the replay.
  Future<void> _readStateOnListen() async {
    try {
      await ref
          .read(lanternServiceProvider)
          .waitForRadiance()
          .timeout(coreWait);
    } catch (_) {
      // Read anyway: a failed read changes nothing.
    }
    if (!ref.mounted) return;
    unawaited(ref.read(serverLocationProvider.notifier).syncSelection());
    unawaited(ref.read(helpersProvider.notifier).liveChanged());
  }
}
