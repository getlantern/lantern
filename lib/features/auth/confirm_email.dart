import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide BackButton;
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/app_pin_field.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

@RoutePage(name: 'ConfirmEmail')
class ConfirmEmail extends HookConsumerWidget {
  final String email;

  /// Optional parameter for new password, used in change email flow
  final String? password;
  final AuthFlow authFlow;

  const ConfirmEmail({
    super.key,
    required this.email,
    this.password,
    this.authFlow = AuthFlow.signUp,
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
        onBackPresses(ref, context);
      },
      child: BaseScreen(
        title: '',
        appBar: CustomAppBar(
          title: Text('confirm_email'.i18n),
          leading: BackButton(
            onPressed: () => onBackPresses(ref, context),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'confirm_email_code'.i18n,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.gray8,
                  fontSize: 14.sp,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppPinField(
              controller: codeController,
              onChanged: (String value) {
                isPinCodeValid.value = value.length == 6;
                appLogger.info('PIN code entered: $value');
              },
              onCompleted: (String value) {
                isPinCodeValid.value = value.length == 6;
                appLogger.info('PIN code completed: $value');
              },
            ),
            SizedBox(height: defaultSize),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppRichText(
                texts: 'confirm_email_code_message'.i18n,
                boldTexts: email,
              ),
            ),
            SizedBox(height: 32),
            PrimaryButton(
              label: 'continue'.i18n,
              enabled: isPinCodeValid.value,
              isTaller: true,
              onPressed: () => onContinueTap(context, ref, codeController.text),
            ),
            SizedBox(height: 24),
            Center(
              child: AppTextButton(
                label: 'resend_email'.i18n,
                textColor: AppColors.black,
                onPressed: () => onResendEmail(context, ref),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> onBackPresses(WidgetRef ref, BuildContext context) async {
    appLogger
        .info('Back button pressed in ConfirmEmail screen Deleting account');
    assert(password != null,
        'Password must be provided to delete account on back press');
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .deleteAccount(email, password!);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        ///reset login status
        ref.read(appSettingNotifierProvider.notifier)
          ..setEmail('')
          ..setUserLoggedIn(false);
        context.hideLoadingDialog();
        appRouter.pop();
      },
    );
  }

  void onContinueTap(BuildContext context, WidgetRef ref, String code) {
    switch (authFlow) {
      case AuthFlow.signUp:
        validateCode(context, ref, code);
        break;
      case AuthFlow.resetPassword:
        validateCode(context, ref, code);
        break;
      case AuthFlow.activationCode:
        validateCode(context, ref, code);
        break;
      case AuthFlow.oauth:
        throw Exception('OAuth flow should not reach this point');
      case AuthFlow.changeEmail:
        completeChangeEmail(context, ref, code);
    }
  }

  Future<void> completeChangeEmail(
      BuildContext context, WidgetRef ref, String code) async {
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .completeChangeEmail(email, password!, code);
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        //update email in app settings
        ref.read(appSettingNotifierProvider.notifier).setEmail(email);
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

  Future<void> validateCode(
      BuildContext context, WidgetRef ref, String code) async {
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .validateRecoveryCode(email, code);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        navigateRoute(code);
      },
    );
  }

  void navigateRoute(String code) {
    switch (authFlow) {
      case AuthFlow.resetPassword:
        appRouter.push(ResetPassword(email: email, code: code));
      case AuthFlow.signUp:
        // Check if user is pro or not
        final isPro =
            sl<LocalStorageService>().getUser()?.legacyUserData.isPro() ??
                false;
        if ((isStoreVersion() || isPro) && PlatformUtils.isMobile) {
          appRouter.push(
              CreatePassword(email: email, authFlow: authFlow, code: code));
          return;
        }
        appRouter.push(
            ChoosePaymentMethod(email: email, authFlow: authFlow, code: code));

        break;
      case AuthFlow.activationCode:
        appRouter.push(ActivationCode(email: email, code: code));
        break;
      case AuthFlow.oauth:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AuthFlow.changeEmail:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void onResendEmail(BuildContext context, WidgetRef ref) {
    switch (authFlow) {
      case AuthFlow.signUp:
        appLogger.info('Resend email for sign up to $email');
        onResendCode(context, ref);
        break;
      case AuthFlow.resetPassword:
        onResendCode(context, ref);
        break;
      case AuthFlow.activationCode:
        throw Exception('activation should not reach this point');
      case AuthFlow.oauth:
        throw Exception('OAuth flow should not reach this point');
      case AuthFlow.changeEmail:
        resendChangeEmail(context, ref);
        break;
    }
  }

  Future<void> resendChangeEmail(BuildContext context, WidgetRef ref) async {
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .startChangeEmail(email, password!);
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
        .read(authNotifierProvider.notifier)
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
