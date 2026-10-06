import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/updater/desktop_update_relay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.getlantern.lantern/method');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const feed =
      'https://update.getlantern.org/update/lantern/appcast.xml?channel=beta';
  const localFeed = 'http://127.0.0.1:12345/token/appcast.xml';
  late DesktopUpdateRelay relay;

  setUp(() {
    relay = DesktopUpdateRelay(platform: TargetPlatform.macOS);
    messenger.setMockMethodCallHandler(
      paths,
      (_) async => '/application-support',
    );
  });
  tearDown(() async {
    await relay.close();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(paths, null);
  });

  test('concurrent starts share one native relay and close once', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'startUpdateRelay' ? localFeed : null;
    });
    expect(await Future.wait([relay.start(feed), relay.start(feed)]), [
      localFeed,
      localFeed,
    ]);
    expect(calls.length, 1);
    expect(calls.single.arguments, {
      'cacheDir': '/application-support/update-transport',
      'feedURL': feed,
    });
    await relay.close();
    await relay.close();
    expect(calls.map((call) => call.method), [
      'startUpdateRelay',
      'stopUpdateRelay',
    ]);
    expect(() => relay.start(feed), throwsStateError);
  });

  test('failed startup can retry', () async {
    var starts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'startUpdateRelay') return null;
      if (++starts == 1) throw PlatformException(code: 'unavailable');
      return localFeed;
    });
    await expectLater(relay.start(feed), throwsA(isA<PlatformException>()));
    expect(await relay.start(feed), localFeed);
    expect(starts, 2);
  });

  test('close waits for pending startup before stopping the relay', () async {
    final started = Completer<void>();
    final address = Completer<String>();
    var stops = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'startUpdateRelay') {
        started.complete();
        return address.future;
      }
      stops++;
      return null;
    });
    final starting = relay.start(feed);
    await started.future;
    final closing = relay.close();
    expect(stops, 0);
    address.complete(localFeed);
    await starting;
    await closing;
    expect(stops, 1);
  });
}
