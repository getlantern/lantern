import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/core/extensions/ref.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

import 'app_robot.dart';
import 'widget_wait_utils.dart';

const _networkTimeout = Duration(seconds: 60);
const _screenTimeout = Duration(seconds: 15);

/// Drives the real auth flows (sign-in, sign-up, recovery, deletion) through
/// the same UI a user touches, against the real backend. Service-level helpers
/// exist only for baseline reset and post-scenario cleanup, never for the flow
/// under test.
class AuthRobot {
  AuthRobot(this.tester, this.app);

  final WidgetTester tester;
  final AppRobot app;

  ProviderContainer? _cachedContainer;

  /// Resolves and caches the root provider container before route changes.
  ProviderContainer get container {
    final cached = _cachedContainer;
    if (cached != null) return cached;

    final elements = app.homeScreen.evaluate();
    if (elements.isEmpty) {
      fail('Cannot resolve providers: home screen is not mounted');
    }
    return _cachedContainer = ProviderScope.containerOf(
      elements.first,
      listen: false,
    );
  }

  bool get isSignedIn => container.read(appSettingProvider).userLoggedIn;

  String get signedInEmail => container.read(userEmailProvider);

  bool get isPro => container.read(isUserProProvider);

  // --- Baseline -------------------------------------------------------------

  /// Establishes the signed-out baseline every scenario starts from. All FTL
  /// cases share one app process, so a previous scenario (or its failure) may
  /// have left a session behind. Uses the service directly — signing out is
  /// not the behavior under test here.
  Future<void> ensureSignedOut() async {
    // Clear leftover routes and dialogs first — after a failed scenario the
    // error dialog and auth screens still cover home, and waiting for home
    // underneath them would just burn the full timeout. Right after
    // app.main() the navigator isn't mounted yet, so only reset when it is.
    if (appRouter.navigatorKey.currentState != null) {
      await app.resetToRoot();
    }
    await app.waitForHomeReady();
    if (isSignedIn) {
      final email = signedInEmail;
      e2eLog('Baseline: signing out $email');
      if (email.isNotEmpty) {
        final result = await container
            .read(lanternServiceProvider)
            .logout(email);
        result.fold(
          (failure) => e2eLog('Baseline logout failed: ${failure.error}'),
          (_) {},
        );
      }
      container.read(homeProvider.notifier).clearLogoutData();
    }
    // Always return to root so a scenario (or its failure) can't leave stale
    // routes or dialogs behind for the next one.
    await app.resetToRoot();
  }

  /// [ensureSignedOut] for `finally` blocks: never throws, so a cleanup
  /// hiccup cannot mask the scenario's real failure. The next scenario's
  /// opening [ensureSignedOut] still enforces the baseline loudly.
  Future<void> tryEnsureSignedOut() async {
    try {
      await ensureSignedOut();
    } catch (error) {
      e2eLog('Cleanup sign-out failed (ignored): $error');
    }
  }

  // --- Sign-in --------------------------------------------------------------

  /// Opens the sign-in email screen through Settings.
  Future<void> openSignInScreen() async {
    await app.openSettings();
    await app.tap(
      find.byKey(const Key('setting.sign_in_tile')),
      name: 'Settings sign-in tile',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.signInEmailField),
      timeout: _screenTimeout,
      reason: 'Sign-in email screen did not open',
    );
  }

  /// Fills the sign-in email and continues to the password screen (no network).
  Future<void> submitSignInEmail(String email) async {
    await _enterText(AuthKeys.signInEmailField, email, name: 'sign-in email');
    await app.tap(
      find.byKey(AuthKeys.signInEmailContinueButton),
      name: 'Sign in with email button',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.signInPasswordField),
      timeout: _screenTimeout,
      reason: 'Sign-in password screen did not open',
    );
  }

  /// Submits the password; the login network call starts here. Does not
  /// settle — a loading dialog animates until the backend responds.
  Future<void> submitSignInPassword(String password) async {
    await _enterText(
      AuthKeys.signInPasswordField,
      password,
      name: 'sign-in password',
    );
    await app.tap(
      find.byKey(AuthKeys.signInPasswordContinueButton),
      name: 'Sign-in continue button',
      settle: false,
    );
  }

  /// Full UI sign-in, waiting until the session is established and the app
  /// has popped back to home.
  Future<void> signIn({required String email, required String password}) async {
    e2eLog('Signing in as $email');
    await openSignInScreen();
    await submitSignInEmail(email);
    await submitSignInPassword(password);
    await waitForSignedIn();
    e2eLog('Signed in as $email');
  }

  Future<void> waitForSignedIn({Duration timeout = _networkTimeout}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (isSignedIn && app.homeScreen.evaluate().isNotEmpty) {
        return;
      }
      // Fail fast with the backend's message instead of timing out when the
      // sign-in error dialog comes up.
      if (find.text('error'.i18n).evaluate().isNotEmpty) {
        fail('Sign-in failed with an error dialog: ${_dialogText()}');
      }
    }
    fail(
      'Not signed in after $timeout. '
      'Visible keys: ${app.visibleKeys().join(', ')}',
    );
  }

  /// All text currently inside the open dialog, for failure messages.
  String _dialogText() {
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .whereType<String>();
    return texts.join(' | ');
  }

  Future<void> waitForSignedOut({Duration timeout = _networkTimeout}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (!isSignedIn) {
        return;
      }
    }
    fail('Still signed in after $timeout');
  }

  /// Waits for the sign-in error dialog (real backend rejection) and
  /// dismisses it.
  Future<void> expectSignInErrorAndDismiss() async {
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.text('error'.i18n),
      timeout: _networkTimeout,
      reason: 'Sign-in error dialog did not appear',
    );
    await app.tap(
      find.widgetWithText(ElevatedButton, 'ok'.i18n),
      name: 'Error dialog OK button',
    );
  }

  // --- Logout / account -----------------------------------------------------

  /// Opens the Account screen through Settings.
  Future<void> openAccountScreen() async {
    await app.openSettings();
    await app.tap(
      find.byKey(const Key('setting.account_tile')),
      name: 'Settings account tile',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.accountLogoutActionButton),
      timeout: _screenTimeout,
      reason: 'Account screen did not open',
    );
  }

  /// Logs out through the Account screen UI and waits for the session to
  /// clear.
  Future<void> logoutViaUi() async {
    await openAccountScreen();
    await app.tap(
      find.byKey(AuthKeys.accountLogoutActionButton),
      name: 'Account logout button',
    );
    await app.tap(
      find.byKey(AuthKeys.accountLogoutConfirmButton),
      name: 'Logout confirm button',
      settle: false,
    );
    await waitForSignedOut();
    await app.resetToRoot();
  }

  // --- Sign-up --------------------------------------------------------------

  /// Reaches the sign-up email screen through the real entry point:
  /// Settings -> Upgrade to Pro -> plans -> Get Lantern Pro.
  Future<void> openSignUpEmailScreen() async {
    // Precondition: AddEmail reroutes to the forgot-password flow (with the
    // stored email, field disabled) when the device's anonymous account is
    // already "registered". That state makes the sign-up flow untestable, so
    // fail with the cause instead of drifting into the wrong flow. Clear the
    // app's data directory to get a fresh anonymous account.
    final user = container.read(homeProvider).value;
    if (user?.legacyUserData.unpassRegistered ?? false) {
      fail(
        'Cannot run the sign-up flow: this install\'s anonymous account is '
        'already registered to "${user!.legacyUserData.email}" '
        '(unpassRegistered=true), so AddEmail would reroute to '
        'forgot-password for that address. Clear the app data directory and '
        'rerun.',
      );
    }

    final opened = await app.openPlansIfFree();
    expect(
      opened,
      isTrue,
      reason:
          'Sign-up entry needs a signed-out (free) state, '
          'but no upgrade button was found',
    );
    await app.tap(
      find.byKey(const Key('plans.cta')),
      name: 'Get Lantern Pro CTA',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.signUpEmailField),
      timeout: _screenTimeout,
      reason: 'Sign-up email screen did not open',
    );
  }

  /// Submits the sign-up email; signup + recovery-start network calls run
  /// behind a loading dialog, so no settle.
  Future<void> submitSignUpEmail(String email) async {
    await _enterText(AuthKeys.signUpEmailField, email, name: 'sign-up email');
    await app.tap(
      find.byKey(AuthKeys.signUpContinueButton),
      name: 'Sign-up continue button',
      settle: false,
    );
  }

  /// Waits for the "account already exists" dialog and dismisses it.
  Future<void> expectSignUpExistsErrorAndDismiss() async {
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.signUpExistsDismissButton),
      timeout: _networkTimeout,
      reason: 'Account-already-exists dialog did not appear',
    );
    expect(
      find.text('create_account_error'.i18n),
      findsOneWidget,
      reason: 'Exists dialog is missing its title',
    );
    await app.tap(
      find.byKey(AuthKeys.signUpExistsDismissButton),
      name: 'Exists dialog OK button',
    );
  }

  // --- Confirm email (OTP) ---------------------------------------------------

  /// Waits for the confirm-email (OTP) screen and verifies it is for
  /// [email] — the screen shows the target address, and asserting it guards
  /// against the flow being silently rerouted to another account (e.g. the
  /// registered-anonymous-account forgot-password branch in AddEmail).
  Future<void> waitForConfirmEmailScreen({required String email}) async {
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.confirmEmailCodeField),
      timeout: _networkTimeout,
      reason: 'Confirm-email screen did not open',
    );
    expect(
      find.textContaining(email, findRichText: true),
      findsWidgets,
      reason: 'Confirm-email screen is not for $email — the flow was '
          'rerouted to a different account',
    );
  }

  Finder get _otpEditable => find.descendant(
    of: find.byKey(AuthKeys.confirmEmailCodeField),
    matching: find.byType(EditableText),
  );

  /// Enters [code] by writing the Pinput's controller, which fires
  /// onCompleted (auto-submit) like real typing. Not tester.enterText:
  /// Pinput closes the IME connection after a completed code
  /// (closeKeyboardWhenCompleted), silently dropping later injected entries.
  Future<void> enterOtp(String code) async {
    e2eLog('Entering OTP');
    await WidgetWaitUtils.waitForFinder(
      tester,
      _otpEditable,
      timeout: _screenTimeout,
      reason: 'OTP input was not available',
    );
    tester.widget<EditableText>(_otpEditable.first).controller.text = code;
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// After a wrong OTP the backend rejects it with a snackbar and the screen
  /// stays put. Clears the field so the next attempt starts fresh.
  Future<void> expectInvalidOtpErrorAndClear() async {
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byType(SnackBar),
      timeout: _networkTimeout,
      reason: 'Invalid-OTP error snackbar did not appear',
    );
    expect(
      find.byKey(AuthKeys.confirmEmailCodeField),
      findsOneWidget,
      reason: 'Should still be on the confirm-email screen after a wrong OTP',
    );
    await WidgetWaitUtils.waitForFinderToDisappear(
      tester,
      find.byType(SnackBar),
      timeout: const Duration(seconds: 10),
      reason: 'Invalid-OTP snackbar did not dismiss',
    );
    // Clear via the controller, same reason as enterOtp.
    tester.widget<EditableText>(_otpEditable.first).controller.clear();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> waitForPaymentMethodScreen() {
    return WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(const Key('choose_payment.list')),
      timeout: _networkTimeout,
      reason: 'Payment-method screen did not appear after OTP confirmation',
    );
  }

  // --- Password recovery ------------------------------------------------------

  /// From the sign-in password screen, starts recovery for [email] up to the
  /// confirm-email (OTP) screen.
  Future<void> startRecoveryFromSignIn(String email) async {
    await openSignInScreen();
    await submitSignInEmail(email);
    await app.tap(
      find.byKey(AuthKeys.signInForgotPasswordButton),
      name: 'Forgot password button',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.resetPasswordEmailField),
      timeout: _screenTimeout,
      reason: 'Reset-password email screen did not open',
    );
    // Email arrives prefilled from the sign-in screen; re-enter defensively so
    // the scenario does not depend on that behavior.
    await _enterText(
      AuthKeys.resetPasswordEmailField,
      email,
      name: 'recovery email',
    );
    await app.tap(
      find.byKey(AuthKeys.resetPasswordEmailNextButton),
      name: 'Recovery next button',
      settle: false,
    );
    await waitForConfirmEmailScreen(email: email);
  }

  Future<void> waitForResetPasswordScreen() {
    return WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.resetPasswordNewPasswordField),
      timeout: _networkTimeout,
      reason: 'Reset-password screen did not open after OTP confirmation',
    );
  }

  /// Fills the new-password form, submits, and closes the success dialog
  /// (back to root).
  Future<void> submitNewPassword(String password) async {
    await _enterText(
      AuthKeys.resetPasswordNewPasswordField,
      password,
      name: 'new password',
    );
    await _enterText(
      AuthKeys.resetPasswordConfirmPasswordField,
      password,
      name: 'confirm new password',
    );
    await app.tap(
      find.byKey(AuthKeys.resetPasswordSubmitButton),
      name: 'Reset password button',
      settle: false,
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.resetPasswordSuccessContinueButton),
      timeout: _networkTimeout,
      reason: 'Password-updated dialog did not appear',
    );
    await app.tap(
      find.byKey(AuthKeys.resetPasswordSuccessContinueButton),
      name: 'Password-updated continue button',
    );
  }

  // --- Account deletion -------------------------------------------------------

  /// Deletes the signed-in account through the UI and waits for the session
  /// to clear.
  Future<void> deleteAccountViaUi(String password) async {
    await openAccountScreen();
    await app.tap(
      find.byKey(AuthKeys.accountDeleteActionButton),
      name: 'Account delete button',
    );
    await _enterText(
      AuthKeys.deleteAccountPasswordField,
      password,
      name: 'delete-account password',
    );
    await app.tap(
      find.byKey(AuthKeys.deleteAccountConfirmButton),
      name: 'Confirm deletion button',
      settle: false,
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.deleteAccountSuccessCloseButton),
      timeout: _networkTimeout,
      reason: 'Account-deleted dialog did not appear',
    );
    await app.tap(
      find.byKey(AuthKeys.deleteAccountSuccessCloseButton),
      name: 'Account-deleted close button',
    );
    await waitForSignedOut();
  }

  // --- Backend helpers (cleanup only) -----------------------------------------

  /// Resets [email]'s password to [password] via the recovery API with the
  /// static smoke OTP. Fails the test when the restore itself fails, since a
  /// broken restore poisons the next run.
  Future<void> resetPasswordViaBackend({
    required String email,
    required String otp,
    required String password,
  }) async {
    e2eLog('Cleanup: restoring password for $email');
    final service = container.read(lanternServiceProvider);
    final started = await service.startRecoveryByEmail(email);
    started.fold(
      (failure) => fail('Cleanup recovery start failed: ${failure.error}'),
      (_) {},
    );
    final completed = await service.completeRecoveryByEmail(
      email: email,
      code: otp,
      newPassword: password,
    );
    completed.fold(
      (failure) => fail('Cleanup password restore failed: ${failure.error}'),
      (_) {},
    );
  }

  // --- Internals ---------------------------------------------------------------

  Future<void> _enterText(Key key, String value, {required String name}) async {
    final finder = find.byKey(key);
    await WidgetWaitUtils.waitForFinder(
      tester,
      finder,
      timeout: _screenTimeout,
      reason: 'Field not visible: $name',
    );
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump(const Duration(milliseconds: 200));

    // A disabled or programmatically-controlled field can swallow enterText
    // (seen with AddEmail when the device's anonymous account is already
    // "registered": the field comes prefilled and disabled). Verify the input
    // actually landed so the flow can't silently continue with other data.
    final editable = find.descendant(
      of: finder,
      matching: find.byType(EditableText),
    );
    if (editable.evaluate().isNotEmpty) {
      final actual = tester.widget<EditableText>(editable.first).controller.text;
      if (actual != value) {
        fail(
          'Field $name did not accept input: expected "$value" but the field '
          'holds "$actual". The field may be disabled or prefilled by app '
          'state (e.g. a registered anonymous account).',
        );
      }
    }
  }
}
