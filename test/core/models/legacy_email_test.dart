import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/user.dart';

void main() {
  UserResponseModel user(String email, {int legacyID = 123}) =>
      UserResponseModel(
        legacyID: legacyID,
        legacyToken: 'test-token',
        emailConfirmed: true,
        success: true,
        legacyUserData: UserDataModel(email: email, unpassRegistered: true),
      );

  test('binding eligibility matches the current legacy identity exactly', () {
    expect(
      user('support+123@getlantern.org').hasLegacyPlaceholderEmail,
      isTrue,
    );
    expect(
      user(' SUPPORT+123@GETLANTERN.ORG ').hasLegacyPlaceholderEmail,
      isTrue,
    );
    for (final email in [
      'support+124@getlantern.org',
      'support+0123@getlantern.org',
      'support+123@example.com',
      'support+123@getlantern.org.example.com',
      'person@example.com',
    ]) {
      expect(user(email).hasLegacyPlaceholderEmail, isFalse, reason: email);
    }
    expect(
      user('support+0@getlantern.org', legacyID: 0).hasLegacyPlaceholderEmail,
      isFalse,
    );
  });

  test(
    'reserved addresses are not usable email and raw account data is preserved',
    () {
      final original = user(' SUPPORT+123@GETLANTERN.ORG ');
      final restored = UserResponseModel.fromJson(original.toJson());
      expect(restored.hasLegacyPlaceholderEmail, isTrue);
      expect(restored.legacyUserData.hasUsableEmail, isFalse);
      expect(restored.toJson(), original.toJson());
      expect(restored.legacyUserData.unpassRegistered, isTrue);
      expect(user('person@example.com').legacyUserData.hasUsableEmail, isTrue);
      expect(user('  ').legacyUserData.hasUsableEmail, isFalse);
      expect(isLegacyPlaceholderEmail('support+456@getlantern.org'), isTrue);
      expect(
        isLegacyPlaceholderEmail('support+someone@getlantern.org'),
        isFalse,
      );
    },
  );
}
