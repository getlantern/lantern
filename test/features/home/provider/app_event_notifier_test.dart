import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Right;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
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
  int syncs = 0;
  @override
  ServerLocation build() =>
      ServerLocation(serverName: '', serverType: ServerLocationType.auto.name);
  @override
  Future<void> syncSelection() async => syncs++;
}

/// Lets the read made when the listener starts finish.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Localization.loadTranslations);
  selectionChangedTests();

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
      await _settle();
      expect(location.syncs, 1, reason: 'one read when the listener starts');
      location.syncs = 0;
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

    test('to the group: names the friend and reads the selection', () async {
      await start(const [sara]);
      await send('{"tag":"$tag","fallback":"personal-proxies"}');
      expect(shown, [
        "Can't reach Sara right now. Switched to Your personal proxies.",
      ]);
      expect(location.syncs, 1, reason: 'reads what radiance selected');
    });

    test('to auto: Smart Location', () async {
      await start(const [sara]);
      await send('{"tag":"$tag","fallback":"auto"}');
      expect(shown, [
        "Can't reach Sara right now. Switched to Smart Location.",
      ]);
      expect(location.syncs, 1);
    });

    test(
      'a friend the view does not know gets the generic helper name',
      () async {
        await start(const []);
        await send('{"tag":"$tag","fallback":"auto"}');
        expect(shown, [
          "Can't reach ${'helper_unnamed'.i18n} right now. Switched to Smart Location.",
        ]);
      },
    );

    test('selection-changed reads the selection, once per event, and '
        'shows nothing', () async {
      await start(const [sara]);
      for (var i = 0; i < 3; i++) {
        service.events.add(
          AppEvent(eventType: 'selection-changed', message: ''),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(location.syncs, 3);
      expect(shown, isEmpty);
    });

    test(
      'a selection event followed at once by snapshots still reads',
      () async {
        await start(const [sara]);
        service.events
          ..add(AppEvent(eventType: 'selection-changed', message: ''))
          ..add(AppEvent(eventType: 'peer-snapshot', message: '{}'))
          ..add(AppEvent(eventType: 'unbounded-snapshot', message: '{}'));
        await Future<void>.delayed(Duration.zero);
        expect(location.syncs, 1);
      },
    );

    test('a malformed event or unknown fallback shows nothing', () async {
      await start(const [sara]);
      await send('not json');
      await send('{"tag":"$tag","fallback":"elsewhere"}');
      expect(shown, isEmpty);
      expect(location.syncs, 0);
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
        serverLocationProvider.overrideWith(_Location.new),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await service.events.close();
    });
    await c.read(appEventProvider.future);
    await _settle();
    expect(helpers.liveChanges, 1, reason: 'one read when the listener starts');
    helpers.liveChanges = 0;

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

  test('a late listener, which missed the country-code event, reads the '
      'country radiance saved', () async {
    CountryCode.update('');
    addTearDown(() => CountryCode.update(''));
    final service = _SettingsService({'country_code': 'ir'});
    final c = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        helpersProvider.overrideWith(_Helpers.new),
        serverLocationProvider.overrideWith(_Location.new),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await service.events.close();
    });
    expect(c.read(countryCodeProvider), '');
    await c.read(appEventProvider.future);
    await _settle();
    expect(c.read(countryCodeProvider), 'IR');
  });
}

class _SettingsService extends _Service {
  _SettingsService(this.settings);
  final Map<String, dynamic> settings;
  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async =>
      Right(settings);
}

/// The real location notifier's view of radiance: each selected_server read
/// gets the next answer.
class _SelectionService extends _Service {
  _SelectionService(this.answers);
  final List<String> answers;
  var _next = 0;
  @override
  Future<Either<Failure, String>> helperCall(
    String op,
    Map<String, dynamic> args,
  ) async => Right('{"tag":"${answers[_next++]}"}');
  @override
  Future<void> updateWidgetLocation({
    required String city,
    required String country,
    required String countryCode,
    required String displayName,
    required String serverName,
  }) async {}
}

class _Storage implements LocalStorageService {
  ServerLocation? location;
  @override
  ServerLocation? getServerLocation() => location;
  @override
  Future<void> saveServerLocation(ServerLocation l) async => location = l;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void selectionChangedTests() {
  test(
    'acknowledged before the switch: the read after the connect sees '
    'friend A, then selection-changed reads friend B, and B is shown',
    () async {
      const a = 'personal-proxy:helper-aaaaaaaaaaaa';
      const b = 'personal-proxy:helper-bbbbbbbbbbbb';
      final storage = _Storage()
        ..location = ServerLocation.personalProxy(
          friendTag: 'helper-aaaaaaaaaaaa',
        );
      sl.registerSingleton<LocalStorageService>(storage);
      addTearDown(sl.reset);
      // The read when the listener starts, the read after the connect, then
      // the read on selection-changed.
      final service = _SelectionService([a, a, b]);
      final c = ProviderContainer(
        overrides: [
          lanternServiceProvider.overrideWithValue(service),
          helpersProvider.overrideWith(_Helpers.new),
          vpnProvider.overrideWithValue(VPNStatus.disconnected),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await service.events.close();
      });
      await c.read(appEventProvider.future);
      await _settle();
      final location = c.read(serverLocationProvider.notifier);

      // The platform acknowledged the connect before switching.
      await location.syncSelection();
      expect(c.read(serverLocationProvider).serverName, a);

      service.events.add(AppEvent(eventType: 'selection-changed', message: ''));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(serverLocationProvider).serverName, b);
      expect(storage.location!.serverName, b);
    },
  );

  test('a late listener, which missed every selection event, still ends on '
      'the selection radiance has', () async {
    const b = 'personal-proxy:helper-bbbbbbbbbbbb';
    final storage = _Storage()
      ..location = ServerLocation.personalProxy(
        friendTag: 'helper-aaaaaaaaaaaa',
      );
    sl.registerSingleton<LocalStorageService>(storage);
    addTearDown(sl.reset);
    final service = _SelectionService([b]);
    final c = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        helpersProvider.overrideWith(_Helpers.new),
        vpnProvider.overrideWithValue(VPNStatus.disconnected),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await service.events.close();
    });
    await c.read(appEventProvider.future);
    await _settle();
    expect(c.read(serverLocationProvider).serverName, b);
  });
}
