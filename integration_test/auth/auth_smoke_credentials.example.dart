/// Template for the auth smoke credentials.
///
/// The auth smoke suite (auth_smoke_test.dart) needs the real roster
/// credentials in `auth_smoke_credentials.dart`, which is gitignored so the
/// passwords never land in the repo. Setup:
///
///   cp integration_test/auth/auth_smoke_credentials.example.dart \
///      integration_test/auth/auth_smoke_credentials.dart
///
/// then fill in the values from the backend smoke roster (engineering#3737).
/// Without that file the suite does not compile — that's the intended
/// fail-fast. CI writes the file from a secret before building.
class AuthSmokeCredentials {
  static const domain = 'getlantern.org';
  static const otp = '123456';
  static const signInPassword = '<password_signin_smoke>';
  static const recoveryPassword = '<password_recovery_smoke>';
  static const deletePassword = '<password_delete_smoke>';
  static const proPassword = '<password_pro_smoke>';
}
