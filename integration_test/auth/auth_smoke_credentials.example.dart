/// Template for providing the auth smoke credentials.
///
/// The committed auth_smoke_credentials.dart is a String.fromEnvironment shim
/// with empty password defaults, so the repo always compiles and analyzes.
/// The suite fails fast at runtime when the passwords are missing. To supply
/// real values (backend smoke roster, engineering#3737):
///
/// **Locally** — create a gitignored `auth_smoke.env` at the repo root and
/// pass it with `--dart-define-from-file=auth_smoke.env`:
///
/// ```
/// AUTH_SMOKE_SIGNIN_PASSWORD=<password_signin_smoke>
/// AUTH_SMOKE_RECOVERY_PASSWORD=<password_recovery_smoke>
/// AUTH_SMOKE_DELETE_PASSWORD=<password_delete_smoke>
/// AUTH_SMOKE_PRO_PASSWORD=<password_pro_smoke>
/// ```
///
/// (AUTH_SMOKE_DOMAIN and AUTH_SMOKE_OTP have working defaults.)
///
/// **CI** — the AUTH_SMOKE_CREDENTIALS secret is the base64 of a consts
/// version of the shim, matching the class below; workflows write it over
/// auth_smoke_credentials.dart before building.
class AuthSmokeCredentials {
  static const domain = 'getlantern.org';
  static const otp = '123456';
  static const signInPassword = '<password_signin_smoke>';
  static const recoveryPassword = '<password_recovery_smoke>';
  static const deletePassword = '<password_delete_smoke>';
  static const proPassword = '<password_pro_smoke>';
}
