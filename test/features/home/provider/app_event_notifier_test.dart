import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
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
  _Helpers([this.initial = const HelpersState()]);
  final HelpersState initial;
  int liveChanges = 0;
  @override
  HelpersState build() => initial;
  @override
  Future<void> liveChanged() async => liveChanges++;
}

class _Location extends ServerLocationNotifier {
  final fallbacks = <(String, String)>[];
  @override
  ServerLocation build() =>
      ServerLocation(serverName: '', serverType: ServerLocationType.auto.name);
  @override
  Future<void> personalProxyFellBack(String friendTag, String fallback) async =>
      fallbacks.add((friendTag, fallback));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Localization.loadTranslations);

  group('personal-proxy-fallback', () {
    const tag = 'helper-0123456789ab';
    late _Service service;
    late _Location location;
    late List<String> shown;
    late ProviderContainer c;

    Future<void> start(List<HelperPairingView> helpers) async {
      service = _Service();
      location = _Location();
      shown = [];
      final original = AppEventNotifier.showMessage;
      addTearDown(() => AppEventNotifier.showMessage = original);
      AppEventNotifier.showMessage = shown.add;
      c = ProviderContainer(
        overrides: [
          lanternServiceProvider.overrideWithValue(service),
          helpersProvider.overrideWith(
            () => _Helpers(
              HelpersState(
                viewLoaded: true,
                view: HelpersView(unlocked: true, helpers: helpers),
              ),
            ),
          ),
          serverLocationProvider.overrideWith(() => location),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await service.events.close();
      });
      await c.read(appEventProvider.future);
    }

    Future<void> send(String message) async {
      service.events.add(
        AppEvent(eventType: 'personal-proxy-fallback', message: message),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    const sara = HelperPairingView(
      pairingId: 'p1',
      name: 'Sara',
      outboundTag: tag,
    );

    test('to the group: names the friend and follows', () async {
      await start(const [sara]);
      await send('{"tag":"$tag","fallback":"personal-proxies"}');
      expect(shown, ['Sara is offline. Switched to Your personal proxies.']);
      expect(location.fallbacks, [(tag, 'personal-proxies')]);
    });

    test('to auto: Smart Location', () async {
      await start(const [sara]);
      await send('{"tag":"$tag","fallback":"auto"}');
      expect(shown, ['Sara is offline. Switched to Smart Location.']);
      expect(location.fallbacks, [(tag, 'auto')]);
    });

    test(
      'a friend the view does not know gets the generic helper name',
      () async {
        await start(const []);
        await send('{"tag":"$tag","fallback":"auto"}');
        expect(shown, [
          '${'helper_unnamed'.i18n} is offline. Switched to Smart Location.',
        ]);
      },
    );

    test('a malformed event or unknown fallback shows nothing', () async {
      await start(const [sara]);
      await send('not json');
      await send('{"tag":"$tag","fallback":"elsewhere"}');
      expect(shown, isEmpty);
      expect(location.fallbacks, isEmpty);
    });
  });

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
