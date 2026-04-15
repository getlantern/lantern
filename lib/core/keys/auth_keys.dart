import 'package:flutter/widgets.dart';

class AuthKeys {
  static const signInEmailField = ValueKey<String>('auth.sign_in.email.field');
  static const signInEmailContinueButton = ValueKey<String>(
    'auth.sign_in.email.continue_button',
  );
  static const signInCreateAccountCta = ValueKey<String>(
    'auth.sign_in.create_account.cta',
  );

  static const signInPasswordField = ValueKey<String>(
    'auth.sign_in.password.field',
  );
  static const signInPasswordContinueButton = ValueKey<String>(
    'auth.sign_in.password.continue_button',
  );

  static const signUpEmailField = ValueKey<String>('auth.sign_up.email.field');
  static const signUpContinueButton = ValueKey<String>(
    'auth.sign_up.email.continue_button',
  );
  static const signUpContinueWithoutEmailButton = ValueKey<String>(
    'auth.sign_up.email.continue_without_email_button',
  );

  static const confirmEmailCodeField = ValueKey<String>(
    'auth.confirm_email.code.field',
  );
  static const confirmEmailContinueButton = ValueKey<String>(
    'auth.confirm_email.continue_button',
  );
  static const confirmEmailResendButton = ValueKey<String>(
    'auth.confirm_email.resend_button',
  );

  static const createPasswordField = ValueKey<String>(
    'auth.create_password.field',
  );
  static const createPasswordContinueButton = ValueKey<String>(
    'auth.create_password.continue_button',
  );

  static const accountLogoutActionButton = ValueKey<String>(
    'auth.account.logout.action_button',
  );
  static const accountLogoutConfirmButton = ValueKey<String>(
    'auth.account.logout.confirm_button',
  );
  static const accountDeleteActionButton = ValueKey<String>(
    'auth.account.delete.action_button',
  );

  static const deleteAccountPasswordField = ValueKey<String>(
    'auth.delete_account.password.field',
  );
  static const deleteAccountConfirmButton = ValueKey<String>(
    'auth.delete_account.confirm_button',
  );
  static const deleteAccountCancelButton = ValueKey<String>(
    'auth.delete_account.cancel_button',
  );
}
