import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/pro_utils.dart';

void main() {
  group('Pro account helpers', () {
    UserResponseModel user({
      String userLevel = 'pro',
      bool unpassRegistered = false,
      String email = 'person@example.com',
    }) {
      return UserResponseModel(
        legacyID: 1,
        legacyToken: 'token',
        emailConfirmed: true,
        success: true,
        legacyUserData: UserDataModel(
          email: email,
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

    test(
      'placeholder Pro accounts need a usable email regardless of login flags',
      () {
        for (final registered in [false, true]) {
          for (final loggedIn in [false, true]) {
            expect(
              shouldShowProAccountSetupDialog(
                user: user(
                  email: 'support+1@getlantern.org',
                  unpassRegistered: registered,
                ),
                userLoggedIn: loggedIn,
              ),
              isTrue,
            );
          }
        }
      },
    );
  });
}
