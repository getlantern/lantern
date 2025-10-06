import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_event_notifier.g.dart';

/// Listens for application-wide events and triggers corresponding actions.
/// This can be used for all listening to events that go sends and handling them
/// in one place.
@Riverpod(keepAlive: true)
class AppEventNotifier extends _$AppEventNotifier {
  @override
  Future<void> build() async {
    watchAppEvents();
  }

  /// Watches for application events and triggers appropriate actions.
  /// Currently, it listens for 'config' events to refresh feature flags.
  void watchAppEvents() {
    appLogger.debug('Setting up app event listener...');
    ref.read(lanternServiceProvider).watchAppEvents().listen((event) {
      final eventType = event.eventType;
      switch (eventType) {
        case 'config':
          appLogger.debug('Received config event, refreshing feature flags.');
          ref.read(featureFlagNotifierProvider.notifier).fetchFeatureFlags();
          break;
        default:
          break;
      }
    });
  }
}
