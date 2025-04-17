import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/stripe_service.dart';
import 'package:lantern/features/auth/provider/payment_notifier.dart';

import '../../core/services/injection_container.dart';

enum _SignUpMethodType { email, google, apple, withoutEmail }

@RoutePage(name: 'AddEmail')
class AddEmail extends StatefulHookConsumerWidget {
  final AuthFlow authFlow;

  const AddEmail({
    super.key,
    this.authFlow = AuthFlow.signUp,
  });

  @override
  ConsumerState<AddEmail> createState() => _AddEmailState();
}

class _AddEmailState extends ConsumerState<AddEmail> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final emailController = useTextEditingController();

    return BaseScreen(
      title: 'add_your_email'.i18n,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: emailController,
              label: 'email'.i18n,
              prefixIcon: AppImagePaths.email,
              hintText: 'example@gmail.com',
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value!.isEmpty) {
                  return null;
                }
                if (value.isNotEmpty) {
                  if (!value.isValidEmail()) {
                    return 'invalid_email'.i18n;
                  }
                }
                return null;
              },
            ),
            SizedBox(height: defaultSize),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: defaultSize),
              child: Text('add_your_email_message'.i18n),
            ),
            SizedBox(height: 32),
            PrimaryButton(
              label: 'continue'.i18n,
              enabled: emailController.text.isValidEmail(),
              onPressed: () => onContinueTap(_SignUpMethodType.email,
                  email: emailController.text),
            ),
            SizedBox(height: defaultSize),
            DividerSpace(),
            SizedBox(height: defaultSize),
            SecondaryButton(
              label: 'continue_with_google'.i18n,
              icon: AppImagePaths.google,
              onPressed: () => onContinueTap(_SignUpMethodType.google),
            ),
            SizedBox(height: defaultSize),
            SecondaryButton(
              label: 'continue_with_apple'.i18n,
              icon: AppImagePaths.apple,
              onPressed: () => onContinueTap(_SignUpMethodType.apple),
            ),
            SizedBox(height: defaultSize),
            DividerSpace(),
            SizedBox(height: defaultSize),
            Center(
              child: AppTextButton(
                label: 'continue_with_email'.i18n,
                textColor: AppColors.gray9,
                onPressed: () => onContinueTap(_SignUpMethodType.withoutEmail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> onContinueTap(_SignUpMethodType type,
      {String email = ''}) async {
    appLogger.debug('Continue tapped with type: $type');
    if (type == _SignUpMethodType.email) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }
    stripeRedirectUrl();
  }

  Future<void> stripeSubscription() async {
    context.showLoadingDialog();

    ///Start subscription flow
    final paymentProvider = ref.read(paymentNotifierProvider.notifier);
    //Stripe
    final result = await paymentProvider.stipeSubscription(
      '1y-usd',
    );

    result.fold(
      (error) {
        context.showSnackBarError(error.localizedErrorMessage);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
      (stripeData) async {
        // Handle success
        context.hideLoadingDialog();

        sl<StripeService>().startStripeSubscription(
          options: StripeOptions.fromJson(stripeData),
          onSuccess: () {},
          onError: (error) {},
        );
      },
    );
  }

  Future<void> stripeRedirectUrl() async {
    context.showLoadingDialog();

    ///Start subscription flow
    final paymentProvider = ref.read(paymentNotifierProvider.notifier);
    //Stripe
    final result = await paymentProvider.stripeSubscriptionLink(
      StipeSubscriptionType.one_time,
      '1y-usd',
    );
    result.fold(
      (error) {
        context.showSnackBarError(error.localizedErrorMessage);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
      (stripeUrl) async {
        // Handle success
        if (stripeUrl.isEmpty) {
          context.showSnackBarError('empty_url'.i18n);
          appLogger.error('Error subscribing to plan: empty url');
          context.hideLoadingDialog();
          return;
        }
        appLogger.info('Successfully started subscription flow');
        context.hideLoadingDialog();
        await Future.delayed(const Duration(milliseconds: 500));
        UrlUtils.openWebview(stripeUrl, 'stripe_payment'.i18n);
      },
    );
  }

  Future<void> triggerInAppPurchase() async {
    final paymentProvider = ref.read(paymentNotifierProvider.notifier);

    final result = await paymentProvider.subscribeToPlan(
      planId: 'planId',
      onSuccess: (purchase) {
        /// Subscription successful
        //todo call api to acknowledge the purchase
        context.hideLoadingDialog();
        // postPaymentNavigate(type);
      },
      onError: (error) {
        ///Error while subscribing
        context.showSnackBarError(error);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
    );
    // Check if got any error while starting subscription flow
    result.fold(
      (error) {
        context.showSnackBarError(error.localizedErrorMessage);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
      (success) {
        // Handle success
        appLogger.info('Successfully started subscription flow');
      },
    );
  }

  void postPaymentNavigate(_SignUpMethodType type) {
    switch (type) {
      case _SignUpMethodType.email:
        // appRouter.push(ConfirmEmail(email: emailController.text));
        break;
      case _SignUpMethodType.google:
        break;
      case _SignUpMethodType.apple:
        break;
      case _SignUpMethodType.withoutEmail:
        appRouter.popUntilRoot();
        break;
    }
  }
}
