import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart' hide BackButton;
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/widgets/app_pin_field.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';

@RoutePage(name: 'ConfirmEmail')
class ConfirmEmail extends HookConsumerWidget {
  final String email;

  /// Password for changing or binding an email address.
  final String? password;
  final AuthFlow authFlow;

  /// The action to resume after a legacy account has its email bound.
  final AuthFlow bindingOrigin;

  /// Web-licensing key to pre-fill on the license screen.
  final String licenseKey;

  const ConfirmEmail({
    super.key,
    required this.email,
    this.password,
    this.authFlow = AuthFlow.signUp,
    this.bindingOrigin = AuthFlow.bindLegacyEmail,
    this.licenseKey = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isPinCodeValid = useState(false);
    final codeController = useTextEditingController();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onBackPresses();
      },
      child: BaseScreen(
        title: '',
        appBar: CustomAppBar(
          title: Text('confirm_email'.i18n),
          leading: BackButton(onPressed: onBackPresses),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'confirm_email_code'.i18n,
                style: textTheme.labelLarge?.copyWith(
                  color: context.textPrimary,
                  fontSize: 14.sp,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppPinField(
              inputKey: AuthKeys.confirmEmailCodeField,
              controller: codeController,
              onChanged: (String value) {
                isPinCodeValid.value = value.length == 6;
              },
              onCompleted: (String value) {
                isPinCodeValid.value = value.length == 6;
                appLogger.info('PIN code completed');
                onContinueTap(context, ref, codeController.text);
              },
            ),
            SizedBox(height: defaultSize),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RichText(
                text: TextSpan(
                  style: textTheme.labelLarge!.copyWith(
                    color: context.textSecondary,
                  ),
                  children: [
                    TextSpan(text: 'confirm_email_code_message_part_one'.i18n),
                    TextSpan(
                      text: '$email.',
                      style: AppTextStyles.labelLargeBold.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(text: 'confirm_email_code_message_part_two'.i18n),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),
            PrimaryButton(
              key: AuthKeys.confirmEmailContinueButton,
              label: 'continue'.i18n,
              enabled: isPinCodeValid.value,
              isTaller: true,
              onPressed: () => onContinueTap(context, ref, codeController.text),
            ),
            SizedBox(height: 24),
            Center(
              child: AppTextButton(
                key: AuthKeys.confirmEmailResendButton,
                label: 'resend_email'.i18n,
                onPressed: () => onResendEmail(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onBackPresses() {
    appLogger.info('Back button pressed in ConfirmEmail screen');
    appRouter.pop();
  }

  void onContinueTap(BuildContext context, WidgetRef ref, String code) {
    switch (authFlow) {
      case AuthFlow.signUp:
        validateCode(context, ref, code);
        break;
      case AuthFlow.resetPassword:
        validateCode(context, ref, code);
        break;
      case AuthFlow.lanternProLicense:
        validateCode(context, ref, code);
        break;
      case AuthFlow.oauth:
        throw Exception('OAuth flow should not reach this point');
      case AuthFlow.changeEmail:
      case AuthFlow.bindLegacyEmail:
        completeChangeEmail(context, ref, code);
      case AuthFlow.renewSubscription:
        throw UnimplementedError();
    }
  }

  Future<void> completeChangeEmail(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    context.showLoadingDialog();
    final auth = ref.read(authProvider.notifier);
    final isBindingEmail = authFlow == AuthFlow.bindLegacyEmail;
    final result = isBindingEmail
        ? await auth.completeBindLegacyEmail(
            email: email,
            password: password!,
            code: code,
          )
        : await auth.completeChangeEmail(email, password!, code);
    if (!context.mounted) return;
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        if (isBindingEmail &&
            failure.error.contains('legacy_email_bound_login_required')) {
          AppDialog.show(
            context: context,
            title: 'add_email'.i18n,
            body: '${'email_updated'.i18n}\n\n${failure.localizedErrorMessage}',
            primaryLabel: 'retry'.i18n,
            secondaryLabel: 'cancel'.i18n,
            onPrimaryPressed: () {
              if (context.mounted) {
                completeChangeEmail(context, ref, code);
              }
            },
          );
          return;
        }
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) async {
        context.hideLoadingDialog();
        if (isBindingEmail) {
          ref.read(appSettingProvider.notifier).setUserLoggedIn(true);
          ref.read(paymentSessionProvider.notifier).clearRedirect();
          TextInput.finishAutofillContext(shouldSave: true);
        }
        final home = ref.read(homeProvider.notifier);
        if (isBindingEmail) {
          await home.reloadUserData();
        } else {
          await home.fetchUserData();
        }
        if (!context.mounted) return;
        if (isBindingEmail) {
          AppDialog.show(
            context: context,
            title: 'add_email'.i18n,
            body: 'email_updated'.i18n,
            primaryLabel: 'ok'.i18n,
            onPrimaryPressed: () {
              if (context.mounted) resumeAfterBinding(context, ref);
            },
          );
          return;
        }
        AppDialog.dialog(
          context: context,
          title: 'change_email'.i18n,
          content: 'email_updated'.i18n,
          action: 'ok'.i18n,
          onPressed: () {
            appRouter.popUntil((route) => (route.settings.name == 'Account'));
          },
        );
      },
    );
  }

  void resumeAfterBinding(BuildContext context, WidgetRef ref) {
    if (bindingOrigin == AuthFlow.signUp && ref.read(isUserProProvider)) {
      AppDialog.showLanternProDialog(
        context: context,
        onPressed: appRouter.popUntilRoot,
      );
      return;
    }
    appRouter.popUntilRoot();
    switch (bindingOrigin) {
      case AuthFlow.signUp:
        if (isStoreVersion()) {
          appRouter.push(Plans());
        } else {
          appRouter.push(
            ChoosePaymentMethod(
              email: email,
              authFlow: AuthFlow.renewSubscription,
            ),
          );
        }
        break;
      case AuthFlow.lanternProLicense:
        appRouter.push(
          LanternProLicense(email: email, code: '', licenseKey: licenseKey),
        );
        break;
      default:
        appRouter.push(Account());
    }
  }

  Future<void> validateCode(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    context.showLoadingDialog();
    final result = await ref
        .read(authProvider.notifier)
        .validateRecoveryCode(email, code);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        navigateRoute(ref, code);
      },
    );
  }

  void navigateRoute(WidgetRef ref, String code) {
    switch (authFlow) {
      case AuthFlow.resetPassword:
        appRouter.push(ResetPassword(email: email, code: code));
      case AuthFlow.signUp:

        /// If user is from store version no need to check anything
        /// send them to create password directly
        if (PlatformUtils.isMobile && isStoreVersion()) {
          appRouter.push(
            CreatePassword(email: email, authFlow: authFlow, code: code),
          );
          return;
        }

        /// Check if user is pro or not
        final isPro = ref.read(isUserProProvider);
        if (isPro) {
          appRouter.push(
            CreatePassword(email: email, authFlow: authFlow, code: code),
          );
          return;
        }
        appRouter.push(
          ChoosePaymentMethod(email: email, authFlow: authFlow, code: code),
        );
        break;
      case AuthFlow.lanternProLicense:
        appRouter.push(
          LanternProLicense(email: email, code: code, licenseKey: licenseKey),
        );
        break;
      case AuthFlow.oauth:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AuthFlow.changeEmail:
      case AuthFlow.bindLegacyEmail:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AuthFlow.renewSubscription:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void onResendEmail(BuildContext context, WidgetRef ref) {
    switch (authFlow) {
      case AuthFlow.resetPassword:
      case AuthFlow.lanternProLicense:
      case AuthFlow.signUp:
        appLogger.info('Resend code requested for ${authFlow.name}');
        onResendCode(context, ref);
        break;
      case AuthFlow.oauth:
        throw Exception('OAuth flow should not reach this point');
      case AuthFlow.changeEmail:
      case AuthFlow.bindLegacyEmail:
        resendChangeEmail(context, ref);
        break;
      case AuthFlow.renewSubscription:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Future<void> resendChangeEmail(BuildContext context, WidgetRef ref) async {
    context.showLoadingDialog();
    final auth = ref.read(authProvider.notifier);
    final result = authFlow == AuthFlow.bindLegacyEmail
        ? await auth.startBindLegacyEmail(email)
        : await auth.startChangeEmail(email, password!);
    if (!context.mounted) return;
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (newEmail) {
        context.hideLoadingDialog();
        context.showSnackBar('email_resend_message'.i18n);
      },
    );
  }

  void onResendCode(BuildContext context, WidgetRef ref) async {
    context.showLoadingDialog();
    final result = await ref
        .read(authProvider.notifier)
        .startRecoveryByEmail(email);
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        context.showSnackBar('email_resend_message'.i18n);
      },
    );
  }
}
