import 'package:lantern/core/localization/i18n.dart';

/// The text for one of lantern-core/helper's error codes.
String helperErrorText(String code) => switch (code) {
  'disabled' => 'helper_error_disabled'.i18n,
  'already_claimed' => 'help_friend_already_claimed_body'.i18n,
  'no_pending_claim' => 'helper_error_no_pending_claim'.i18n,
  'too_many_invites' => 'helper_error_too_many_invites'.i18n,
  'too_many_pairings' => 'helper_error_too_many_pairings'.i18n,
  'bad_link' => 'help_friend_bad_link'.i18n,
  'bad_name' => 'helper_error_bad_name'.i18n,
  'own_invite' => 'help_friend_own_invite'.i18n,
  'keystore' => 'helper_error_keystore'.i18n,
  'keystore_reset' => 'helper_error_keystore_reset'.i18n,
  _ => 'helper_error_unavailable'.i18n,
};
