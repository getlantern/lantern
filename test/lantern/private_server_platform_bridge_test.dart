import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.getlantern.lantern/method');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('private server imports require certificate verification', () async {
    const urls = 'trojan://password@example.com:443?allowInsecure=1';
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return '["private-server"]';
    });

    final result = await LanternPlatformService().addServerBasedOnURLs(
      urls: urls,
    );

    result.fold(
      (failure) => fail('private server import failed: $failure'),
      (tags) => expect(tags, ['private-server']),
    );
    expect(calls, hasLength(1));
    expect(calls.single.method, 'addServerBasedOnURLs');
    expect(calls.single.arguments, {
      'urls': urls,
      'skipValidation': false,
      'serverName': '',
    });
  });
}
