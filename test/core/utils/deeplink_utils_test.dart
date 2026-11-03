import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';

void main() {
  group('isOAuthCallbackResult', () {
    test('accepts a success callback', () {
      expect(
        isOAuthCallbackResult(Uri.parse('lantern://auth?token=abc')),
        isTrue,
      );
    });

    test('accepts a device-limit callback', () {
      expect(
        isOAuthCallbackResult(
          Uri.parse(
            'lantern://auth?result=false&token=abc&device%5Bid1%5D=Phone',
          ),
        ),
        isTrue,
      );
    });

    test('accepts a failure callback', () {
      expect(
        isOAuthCallbackResult(
          Uri.parse('lantern://auth?result=false&error=unable_to_get_email'),
        ),
        isTrue,
      );
    });

    test('rejects a callback with no outcome', () {
      expect(isOAuthCallbackResult(Uri.parse('lantern://auth')), isFalse);
    });
  });

  group('oAuthErrorMessageKey', () {
    test('maps codes with a dedicated message', () {
      expect(
        oAuthErrorMessageKey('unable_to_restore_session'),
        'oauth_error_session_expired',
      );
      expect(
        oAuthErrorMessageKey('unable_to_authenticate'),
        'oauth_error_provider_failed',
      );
      expect(
        oAuthErrorMessageKey('unable_to_get_email'),
        'oauth_error_no_email',
      );
      expect(
        oAuthErrorMessageKey('unable_to_add_device'),
        'oauth_error_add_device',
      );
    });

    test('falls back to the generic message for other codes', () {
      for (final code in [
        'unable_to_accept_return_address',
        'unable_to_find_user',
        'unable_to_sign_up',
        'unable_to_get_devices',
        'unable_to_sign_token',
        'something_new',
        '',
        null,
      ]) {
        expect(
          oAuthErrorMessageKey(code),
          oAuthSignInFailedKey,
          reason: '$code',
        );
      }
    });
  });
}
