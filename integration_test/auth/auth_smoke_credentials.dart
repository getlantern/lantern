/// Auth smoke credentials, sourced from --dart-define at build time.
///
/// This committed shim keeps the repo compiling and analyzing without any
/// secrets checked in. Real values come from one of:
/// - locally: `--dart-define-from-file=auth_smoke.env` (gitignored, repo
///   root — see auth_smoke_credentials.example.dart for the format);
/// - CI: the AUTH_SMOKE_CREDENTIALS secret, a base64-encoded consts version
///   of this file that overwrites it before the build.
///
/// Passwords default to empty; the suite fails fast at runtime when they are
/// missing (see registerAuthSmokeTests). Never put real passwords in this
/// file — it is tracked by git.
class AuthSmokeCredentials {
  static const domain = String.fromEnvironment(
    'AUTH_SMOKE_DOMAIN',
    defaultValue: 'getlantern.org',
  );
  static const otp = String.fromEnvironment(
    'AUTH_SMOKE_OTP',
    defaultValue: '123456',
  );
  static const signInPassword = String.fromEnvironment(
    'AUTH_SMOKE_SIGNIN_PASSWORD',
  );
  static const recoveryPassword = String.fromEnvironment(
    'AUTH_SMOKE_RECOVERY_PASSWORD',
  );
  static const deletePassword = String.fromEnvironment(
    'AUTH_SMOKE_DELETE_PASSWORD',
  );
  static const proPassword = String.fromEnvironment(
    'AUTH_SMOKE_PRO_PASSWORD',
  );
}
