import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.getlantern.lantern/method');
  const signInUrl = 'https://df.iantem.io/users/oauth2/google';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void respondWith(Future<Object?> Function() reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'authenticateInApp');
      expect(call.arguments, signInUrl);
      return reply();
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('authenticateInApp returns the callback URL', () async {
    respondWith(() async => 'lantern://auth?token=abc');
    final result = await LanternPlatformService().authenticateInApp(signInUrl);
    expect(result.getRight().toNullable()?.queryParameters, {'token': 'abc'});
  });

  test(
    'authenticateInApp returns null when the user closes the sheet',
    () async {
      respondWith(() async => null);
      final result = await LanternPlatformService().authenticateInApp(
        signInUrl,
      );
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), isNull);
    },
  );

  test('authenticateInApp fails when the sheet cannot start', () async {
    respondWith(() async => throw PlatformException(code: 'AUTH_SESSION'));
    final result = await LanternPlatformService().authenticateInApp(signInUrl);
    expect(result.isLeft(), isTrue);
  });
}
