import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/auth_robot.dart';
import 'auth_smoke_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAuthSmokeTests();
}

/// End-to-end auth smoke suite against the real backend, using the dedicated
/// smoke accounts provisioned in engineering#3737 (static OTP, no email
/// delivery, lockout tolerance, metrics exclusion, per-account passwords,
/// allow_resignup for signup_smoke@, skip_delete for delete_smoke@).
/// Credentials come from the gitignored auth_smoke_credentials.dart — see
/// auth_smoke_credentials.example.dart for setup.
///
/// Exposed so an aggregator entrypoint (android_all_e2e_test.dart) can
/// register this suite alongside others. All cases share one app process, so
/// each scenario establishes its own signed-out baseline and restores any
/// state it mutates (password resets, created accounts).
void registerAuthSmokeTests() {
  group('Auth smoke test', () {
    testWidgets(
      'sign in succeeds and logout clears the session',
      (tester) async {
        final password = signInSmokePassword;
        await app.main();
        final appRobot = AppRobot(tester);
        final auth = AuthRobot(tester, appRobot);
        await auth.ensureSignedOut();
        try {
          await auth.signIn(email: signInSmokeEmail, password: password);
          expect(auth.isSignedIn, isTrue);
          expect(auth.signedInEmail.toLowerCase(), signInSmokeEmail);

          await auth.logoutViaUi();
          expect(auth.isSignedIn, isFalse);
          expect(auth.signedInEmail, isEmpty);
        } finally {
          await auth.tryEnsureSignedOut();
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'sign in with a wrong password shows the backend error',
      (tester) async {
        final wrongPassword = wrongAuthSmokePassword;
        await app.main();
        final appRobot = AppRobot(tester);
        final auth = AuthRobot(tester, appRobot);
        await auth.ensureSignedOut();
        try {
          await auth.openSignInScreen();
          await auth.submitSignInEmail(signInSmokeEmail);
          await auth.submitSignInPassword(wrongPassword);
          await auth.expectSignInErrorAndDismiss();
          expect(auth.isSignedIn, isFalse);
        } finally {
          await auth.tryEnsureSignedOut();
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'sign up reaches the payment-method screen via OTP and backs out',
      (tester) async {
        await app.main();
        final appRobot = AppRobot(tester);
        final auth = AuthRobot(tester, appRobot);
        await auth.ensureSignedOut();
        try {
          await auth.openSignUpEmailScreen();
          await auth.submitSignUpEmail(signUpSmokeEmail);
          await auth.waitForConfirmEmailScreen(email: signUpSmokeEmail);

          // Wrong OTP first: the confirm-email screen must reject it and
          // stay put.
          await auth.enterOtp(authSmokeWrongOtp);
          await auth.expectInvalidOtpErrorAndClear();

          await auth.enterOtp(authSmokeOtp);
          await auth.waitForPaymentMethodScreen();

          // Back out without purchasing; no session should exist.
          await appRobot.resetToRoot();
          expect(auth.isSignedIn, isFalse);
        } finally {
          // No cleanup needed: signup_smoke@ is provisioned with
          // allow_resignup, so the next run can sign up with it again.
          await auth.tryEnsureSignedOut();
        }
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );

    testWidgets(
      'sign up with an existing account shows the exists error',
      (tester) async {
        await app.main();
        final appRobot = AppRobot(tester);
        final auth = AuthRobot(tester, appRobot);
        await auth.ensureSignedOut();
        try {
          await auth.openSignUpEmailScreen();
          await auth.submitSignUpEmail(signUpExistsSmokeEmail);
          await auth.expectSignUpExistsErrorAndDismiss();
          expect(auth.isSignedIn, isFalse);
        } finally {
          await auth.tryEnsureSignedOut();
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'password recovery resets and restores the password',
      (tester) async {
        final fixedPassword = recoverySmokePassword;
        final tempPassword = tempAuthSmokePassword;
        await app.main();
        final appRobot = AppRobot(tester);
        final auth = AuthRobot(tester, appRobot);
        await auth.ensureSignedOut();
        var passwordChanged = false;
        try {
          await auth.startRecoveryFromSignIn(recoverySmokeEmail);

          // Wrong OTP first on the recovery screen.
          await auth.enterOtp(authSmokeWrongOtp);
          await auth.expectInvalidOtpErrorAndClear();

          await auth.enterOtp(authSmokeOtp);
          await auth.waitForResetPasswordScreen();
          passwordChanged = true;
          await auth.submitNewPassword(tempPassword);

          // The new password must actually work end to end.
          await auth.signIn(email: recoverySmokeEmail, password: tempPassword);
          expect(auth.isSignedIn, isTrue);
        } finally {
          await auth.tryEnsureSignedOut();
          if (passwordChanged) {
            // Restore the fixed password so the account is usable next run.
            await auth.resetPasswordViaBackend(
              email: recoverySmokeEmail,
              otp: authSmokeOtp,
              password: fixedPassword,
            );
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );

    testWidgets(
      'account deletion clears the session and stays reusable',
      (tester) async {
        final password = deleteSmokePassword;
        await app.main();
        final appRobot = AppRobot(tester);
        final auth = AuthRobot(tester, appRobot);
        await auth.ensureSignedOut();
        try {
          await auth.signIn(email: deleteSmokeEmail, password: password);
          await auth.deleteAccountViaUi(password);
          expect(auth.isSignedIn, isFalse);
          await appRobot.resetToRoot();

          // delete_smoke@ is provisioned with skip_delete: the backend accepts
          // the deletion (the client flow completes) but retains the account so
          // the scenario is reusable next run. Verify that contract holds.
          final login = await auth.container
              .read(lanternServiceProvider)
              .login(email: deleteSmokeEmail, password: password);
          expect(
            login.isRight(),
            isTrue,
            reason:
                'delete_smoke@ should remain usable after deletion '
                '(skip_delete roster contract)',
          );
        } finally {
          await auth.tryEnsureSignedOut();
        }
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );

    testWidgets(
      'pro account signs in with Pro entitlements',
      (tester) async {
        final password = proSmokePassword;
        await app.main();
        final appRobot = AppRobot(tester);
        final auth = AuthRobot(tester, appRobot);
        await auth.ensureSignedOut();
        try {
          await auth.signIn(email: proSmokeEmail, password: password);
          expect(
            auth.isPro,
            isTrue,
            reason: 'pro_smoke account did not come back as Pro',
          );

          // No upgrade prompt anywhere: Settings must not offer Upgrade to Pro.
          expect(
            await appRobot.openPlansIfFree(),
            isFalse,
            reason: 'Pro account still shows the Upgrade to Pro entry',
          );
          await appRobot.resetToRoot();
        } finally {
          await auth.tryEnsureSignedOut();
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
