import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/app_setting.dart';

void main() {
  group('AppSetting.clearAuthSessionData', () {
    test('clears auth/session fields by default', () {
      const before = AppSetting(
        isPro: true,
        userLoggedIn: true,
        oAuthToken: 'token-123',
        oAuthLoginProvider: 'google',
        email: 'user@example.com',
        environment: 'stage',
        locale: 'en_US',
      );

      final after = before.clearAuthSessionData();

      expect(after.isPro, isFalse);
      expect(after.userLoggedIn, isFalse);
      expect(after.oAuthToken, isEmpty);
      expect(after.oAuthLoginProvider, isEmpty);
      expect(after.email, isEmpty);
      expect(after.environment, equals('stage'));
      expect(after.locale, equals('en_US'));
    });

    test('can preserve email when requested', () {
      const before = AppSetting(
        isPro: true,
        userLoggedIn: true,
        oAuthToken: 'token-123',
        oAuthLoginProvider: 'apple',
        email: 'user@example.com',
      );

      final after = before.clearAuthSessionData(clearEmail: false);

      expect(after.isPro, isFalse);
      expect(after.userLoggedIn, isFalse);
      expect(after.oAuthToken, isEmpty);
      expect(after.oAuthLoginProvider, isEmpty);
      expect(after.email, equals('user@example.com'));
    });
  });
}
