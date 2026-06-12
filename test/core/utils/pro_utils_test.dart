import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/pro_utils.dart';

void main() {
  group('Pro account helpers', () {
    UserResponseModel user({
      String userLevel = 'pro',
      bool unpassRegistered = false,
    }) {
      return UserResponseModel(
        legacyID: 1,
        legacyToken: 'token',
        emailConfirmed: true,
        success: true,
        legacyUserData: UserDataModel(
          email: 'person@example.com',
          userLevel: userLevel,
          unpassRegistered: unpassRegistered,
        ),
      );
    }

    test('detects locally registered Pro accounts', () {
      expect(hasRegisteredProAccount(user(unpassRegistered: true)), isTrue);
      expect(hasRegisteredProAccount(user()), isFalse);
      expect(
        hasRegisteredProAccount(
          user(userLevel: 'free', unpassRegistered: true),
        ),
        isFalse,
      );
      expect(hasRegisteredProAccount(null), isFalse);
    });

    test('shows setup only for unregistered signed-out Pro accounts', () {
      expect(
        shouldShowProAccountSetupDialog(user: user(), userLoggedIn: false),
        isTrue,
      );
      expect(
        shouldShowProAccountSetupDialog(
          user: user(unpassRegistered: true),
          userLoggedIn: false,
        ),
        isFalse,
      );
      expect(
        shouldShowProAccountSetupDialog(user: user(), userLoggedIn: true),
        isFalse,
      );
    });
  });
}
