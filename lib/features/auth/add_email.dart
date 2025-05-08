import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/features/auth/provider/oauth_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

enum SignUpMethodType { email, google, apple, withoutEmail }

@RoutePage(name: 'AddEmail')
class AddEmail extends StatefulHookConsumerWidget {
  final AuthFlow authFlow;
  final AppFlow appFlow;

  const AddEmail({
    super.key,
    this.authFlow = AuthFlow.signUp,
    this.appFlow = AppFlow.nonStore,
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
        child: SingleChildScrollView(
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
                onPressed: () => onContinueTap(SignUpMethodType.email,
                    email: emailController.text),
              ),
              SizedBox(height: defaultSize),
              DividerSpace(),
              SizedBox(height: defaultSize),
              OAuthLogin(
                methodType: SignUpMethodType.google,
                onResult: (token) =>
                    onWebViewResult(token, SignUpMethodType.google),
              ),
              SizedBox(height: defaultSize),
              OAuthLogin(
                methodType: SignUpMethodType.apple,
                onResult: (token) =>
                    onWebViewResult(token, SignUpMethodType.apple),
              ),
              SizedBox(height: defaultSize),
              DividerSpace(),
              SizedBox(height: defaultSize),
              if (widget.appFlow == AppFlow.store)
                Center(
                  child: AppTextButton(
                    label: 'continue_with_email'.i18n,
                    textColor: AppColors.gray9,
                    onPressed: () =>
                        onContinueTap(SignUpMethodType.withoutEmail),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> onContinueTap(SignUpMethodType type, {String email = ''}) async {
    appLogger.debug('Continue tapped with type: $type');
    if (type == SignUpMethodType.email) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      postPaymentNavigate(type, email);
    }
  }

  Future<void> onWebViewResult(
      Map<String, dynamic> result, SignUpMethodType type) async {
    final token = result['token'];
    if (token != null) {
      context.showLoadingDialog();
      final result = await ref
          .read(oAuthNotifierProvider.notifier)
          .oAuthLoginCallback(token);
      result.fold(
        (failure) {
          context.hideLoadingDialog();
          context.showSnackBarError(failure.localizedErrorMessage);
        },
        (response) {
          context.hideLoadingDialog();
          ref.read(homeNotifierProvider.notifier).updateUserData(response);
          appLogger.debug('Login Response: ${response.toString()}');
          postPaymentNavigate(type, response.legacyUserData.email);
        },
      );
    } else {
      context.showSnackBarError('Failed to retrieve token');
    }
  }

  // void navigateAuth() {
  //   switch (widget.authFlow) {
  //     case AuthFlow.resetPassword:
  //       // TODO: Handle this case.
  //       throw UnimplementedError();
  //     case AuthFlow.signUp:
  //       // TODO: Handle this case.
  //       throw UnimplementedError();
  //     case AuthFlow.activationCode:
  //       // TODO: Handle this case.
  //       throw UnimplementedError();
  //   }
  // }

  void postPaymentNavigate(SignUpMethodType type, String email) {
    switch (type) {
      case SignUpMethodType.apple:
      case SignUpMethodType.google:
        appRouter
            .push(ChoosePaymentMethod(email: email, authFlow: AuthFlow.signUp));
        break;
      case SignUpMethodType.email:
        appRouter.push(ConfirmEmail(email: email, authFlow: widget.authFlow));
        break;
      case SignUpMethodType.withoutEmail:
        appRouter.popUntilRoot();
        break;
    }
  }
}
