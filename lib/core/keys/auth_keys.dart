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

  static const signInForgotPasswordButton = ValueKey<String>(
    'auth.sign_in.forgot_password_button',
  );

  static const signUpExistsSignInButton = ValueKey<String>(
    'auth.sign_up.exists.sign_in_button',
  );
  static const signUpExistsDismissButton = ValueKey<String>(
    'auth.sign_up.exists.dismiss_button',
  );

  static const resetPasswordEmailField = ValueKey<String>(
    'auth.reset_password.email.field',
  );
  static const resetPasswordEmailNextButton = ValueKey<String>(
    'auth.reset_password.email.next_button',
  );
  static const resetPasswordNewPasswordField = ValueKey<String>(
    'auth.reset_password.new_password.field',
  );
  static const resetPasswordConfirmPasswordField = ValueKey<String>(
    'auth.reset_password.confirm_password.field',
  );
  static const resetPasswordSubmitButton = ValueKey<String>(
    'auth.reset_password.submit_button',
  );
  static const resetPasswordSuccessContinueButton = ValueKey<String>(
    'auth.reset_password.success.continue_button',
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
  static const deleteAccountSuccessCloseButton = ValueKey<String>(
    'auth.delete_account.success.close_button',
  );
}
