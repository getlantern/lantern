import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_pin_field.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';

@RoutePage(name: 'ConfirmEmail')
class ConfirmEmail extends HookWidget {
  final String email;
  final AuthFlow authFlow;
  final AppFlow appFlow;

  const ConfirmEmail({
    super.key,
    required this.email,
    this.authFlow = AuthFlow.signUp,
    this.appFlow = AppFlow.nonStore,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isPinCodeValid = useState(false);

    return BaseScreen(
      title: 'confirm_email'.i18n,
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
            onChanged: (String value) {
              isPinCodeValid.value = value.length == 6;
              appLogger.info('PIN code entered: $value');
            },
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppRichText(
              texts: 'confirm_email_code_message'.i18n,
              boldTexts: 'example@gmail.com',
            ),
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'continue'.i18n,
            enabled: isPinCodeValid.value,
            onPressed: onContinueTap,
          ),
          SizedBox(height: 24),
          Center(
            child: AppTextButton(
              label: 'resend_email'.i18n,
              textColor: AppColors.black,
              onPressed: () {},
            ),
          )
        ],
      ),
    );
  }

  void onContinueTap() {
    switch (authFlow) {
      case AuthFlow.signUp:
        if (appFlow == AppFlow.store) {
          appRouter.push(CreatePassword(email: email));
          return;
        }
        appRouter.push(ChoosePaymentMethod(email: email, authFlow: authFlow));
        break;
      case AuthFlow.resetPassword:
        appRouter.push(ResetPassword(email: email));
        break;
      case AuthFlow.activationCode:
        appRouter.push(ActivationCode());
        break;
    }
  }

  void onResendEmail() {
    switch (authFlow) {
      case AuthFlow.signUp:
        appLogger.info('Resend email for sign up to $email');
        break;
      case AuthFlow.resetPassword:
        appLogger.info('Resend email for reset password to $email');
        break;
      case AuthFlow.activationCode:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
