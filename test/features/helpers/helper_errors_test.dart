import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/helpers/helper_errors.dart';

void main() {
  // Without loaded translations, .i18n answers the msgid itself.
  test('every engine and app error code has text', () {
    const expected = {
      'locked': 'helper_error_unavailable',
      'disabled': 'helper_error_disabled',
      'not_found': 'helper_error_unavailable',
      'already_claimed': 'help_friend_already_claimed_body',
      'no_pending_claim': 'helper_error_no_pending_claim',
      'too_many_invites': 'helper_error_too_many_invites',
      'too_many_pairings': 'helper_error_too_many_pairings',
      'bad_link': 'help_friend_bad_link',
      'bad_name': 'helper_error_bad_name',
      'own_invite': 'help_friend_own_invite',
      'unavailable': 'helper_error_unavailable',
      'internal': 'helper_error_unavailable',
      'keystore': 'helper_error_keystore',
      'keystore_reset': 'helper_error_keystore_reset',
    };
    expected.forEach(
      (code, msgid) => expect(helperErrorText(code), msgid, reason: code),
    );
  });

  test('every helper_error msgid is in en.po', () {
    final po = File('assets/locales/en.po').readAsStringSync();
    for (final id in [
      'helper_error_disabled',
      'helper_error_unavailable',
      'helper_error_too_many_invites',
      'helper_error_too_many_pairings',
      'helper_error_no_pending_claim',
      'helper_error_bad_name',
      'helper_error_keystore',
      'helper_error_keystore_reset',
    ]) {
      expect(po, contains('msgid "$id"'), reason: id);
    }
  });
}
