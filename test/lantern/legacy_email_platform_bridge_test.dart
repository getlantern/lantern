import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.getlantern.lantern/method');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'binding uses the dedicated native methods and accepts an empty response',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      final service = LanternPlatformService();
      expect(
        (await service.startBindLegacyEmail('person@example.com')).isRight(),
        isTrue,
      );
      expect(
        (await service.completeBindLegacyEmail(
          email: 'person@example.com',
          password: 'new-password',
          code: '123456',
        )).isRight(),
        isTrue,
      );
      expect(calls.map((call) => call.method), [
        'startBindLegacyEmail',
        'completeBindLegacyEmail',
      ]);
      expect(calls[0].arguments, {'email': 'person@example.com'});
      expect(calls[1].arguments, {
        'email': 'person@example.com',
        'password': 'new-password',
        'code': '123456',
      });
    },
  );

  test('native binding errors remain failures', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'invalid_code', message: 'Invalid code');
    });
    final service = LanternPlatformService();
    expect(
      (await service.startBindLegacyEmail('person@example.com')).isLeft(),
      isTrue,
    );
    expect(
      (await service.completeBindLegacyEmail(
        email: 'person@example.com',
        password: 'new-password',
        code: '123456',
      )).isLeft(),
      isTrue,
    );
  });
}
