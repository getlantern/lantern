import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  final events = StreamController<AppEvent>.broadcast(sync: true);
  @override
  Stream<AppEvent> watchAppEvents() => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Helpers extends HelpersNotifier {
  int liveChanges = 0;
  @override
  HelpersState build() => const HelpersState();
  @override
  Future<void> liveChanged() async => liveChanges++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('helper-live re-reads the helper view, once per event, and nothing '
      'else does', () async {
    final service = _Service();
    final helpers = _Helpers();
    final c = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        helpersProvider.overrideWith(() => helpers),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await service.events.close();
    });
    await c.read(appEventProvider.future);

    service.events.add(AppEvent(eventType: 'helper-live', message: '{}'));
    await Future<void>.delayed(Duration.zero);
    expect(helpers.liveChanges, 1);

    service.events.add(AppEvent(eventType: 'peer-snapshot', message: '{}'));
    await Future<void>.delayed(Duration.zero);
    expect(helpers.liveChanges, 1);

    service.events.add(AppEvent(eventType: 'helper-live', message: '{}'));
    await Future<void>.delayed(Duration.zero);
    expect(helpers.liveChanges, 2);
  });
}
