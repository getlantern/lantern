import 'auth_smoke_credentials.example.dart';

/// Roster for the auth smoke suite.
///
/// The backend accounts are provisioned server-side (engineering#3737) with a
/// static recovery OTP, no email delivery, lockout tolerance, and metrics
/// exclusion. Each account has its own password. Roster properties that the
/// scenarios rely on:
/// - `signup_smoke@` allows repeated sign-ups (`allow_resignup`), so the
///   sign-up scenario needs no delete-cleanup;
/// - `delete_smoke@` is never actually deleted server-side (`skip_delete`),
///   so the account stays reusable across runs.
///
/// Credentials live in auth_smoke_credentials.dart, which is gitignored —
/// see auth_smoke_credentials.example.dart for setup.
const authSmokeOtp = AuthSmokeCredentials.otp;
const authSmokeWrongOtp = '000000';

const signInSmokeEmail = 'signin_smoke@${AuthSmokeCredentials.domain}';
const signUpSmokeEmail = 'signup_smoke@${AuthSmokeCredentials.domain}';
const signUpExistsSmokeEmail =
    'signup_exists_smoke@${AuthSmokeCredentials.domain}';
const recoverySmokeEmail = 'recovery_smoke@${AuthSmokeCredentials.domain}';
const deleteSmokeEmail = 'delete_smoke@${AuthSmokeCredentials.domain}';
const proSmokeEmail = 'pro_smoke@${AuthSmokeCredentials.domain}';

const signInSmokePassword = AuthSmokeCredentials.signInPassword;
const recoverySmokePassword = AuthSmokeCredentials.recoveryPassword;
const deleteSmokePassword = AuthSmokeCredentials.deletePassword;
const proSmokePassword = AuthSmokeCredentials.proPassword;

/// A deliberately wrong password for the sign-in failure scenario. Derived so
/// it can never collide with the real one.
const wrongAuthSmokePassword = '$signInSmokePassword-Wrong1!';

/// Temporary password the recovery scenario sets before restoring the fixed
/// one. Suffix keeps it satisfying the app's password criteria as long as the
/// fixed password does.
const tempAuthSmokePassword = '$recoverySmokePassword-Tmp1!';
