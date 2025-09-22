import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

enum SignUpMethodType { email, google, apple, withoutEmail }

@RoutePage(name: 'AddEmail')
class AddEmail extends StatefulHookConsumerWidget {
  final AuthFlow authFlow;

  ///password will be used for change email flow
  /// all other times it will be null
  final String? password;

  const AddEmail({super.key, this.authFlow = AuthFlow.signUp, this.password});

  @override
  ConsumerState<AddEmail> createState() => _AddEmailState();
}

class _AddEmailState extends ConsumerState<AddEmail> {
  final _formKey = GlobalKey<FormState>();
  TextTheme? textTheme;

  @override
  Widget build(BuildContext context) {
    final emailController = useTextEditingController();
    textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: widget.authFlow == AuthFlow.changeEmail
          ? 'enter_new_email'.i18n
          : 'add_your_email'.i18n,
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
              if (widget.authFlow == AuthFlow.changeEmail)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: defaultSize),
                  child: Text('change_email_message'.i18n,
                      style: textTheme!.bodyMedium!.copyWith(
                        color: AppColors.gray6,
                      )),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: defaultSize),
                  child: Text('add_your_email_message'.i18n,
                      style: textTheme!.bodyMedium!.copyWith(
                        color: AppColors.gray6,
                      )),
                ),
              SizedBox(height: 32),
              PrimaryButton(
                label: 'continue'.i18n,
                enabled: emailController.text.isValidEmail(),
                onPressed: () => onContinueTap(
                  SignUpMethodType.email,
                  emailController.text,
                ),
              ),
              SizedBox(height: defaultSize),
              DividerSpace(),
              SizedBox(height: defaultSize),
              OAuthLogin(
                methodType: SignUpMethodType.google,
                onResult: (token) =>
                    onOAuthResult(token, SignUpMethodType.google),
              ),
              SizedBox(height: defaultSize),
              OAuthLogin(
                methodType: SignUpMethodType.apple,
                onResult: (token) =>
                    onOAuthResult(token, SignUpMethodType.apple),
              ),
              SizedBox(height: defaultSize),
              DividerSpace(),
              SizedBox(height: defaultSize),
              if (isStoreVersion())
                Center(
                  child: AppTextButton(
                    label: 'continue_without_email'.i18n,
                    textColor: AppColors.gray9,
                    onPressed: () =>
                        navigateRoute(SignUpMethodType.withoutEmail, ""),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> onContinueTap(SignUpMethodType type, String email) async {
    appLogger.debug('Continue tapped with type: $type');
    try {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      if (widget.authFlow == AuthFlow.changeEmail) {
        //Change email flow
        appLogger.debug('Starting change email flow');
        startChangeEmailFlow(email);
      } else {
        appLogger.debug('Starting signup flow');
        await signupFlow(email);
        return;
      }
    } catch (e) {
      appLogger.error('Error in onContinueTap: $e');
      context.showSnackBar('error_occurred'.i18n);
    }
  }

  Future<void> signupFlow(String email) async {
    context.showLoadingDialog();

    final result = await ref
        .read(authNotifierProvider.notifier)
        .signUpWithEmail(email, generatePassword());

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (response) {
        //sign up successful
        //start forgot password flow
        context.hideLoadingDialog();
        ref.read(appSettingNotifierProvider.notifier)
          ..setEmail(email)
          ..setUserLoggedIn(true);
        startForgotPasswordFlow(email);
      },
    );
  }

  Future<void> startForgotPasswordFlow(String email) async {
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
        navigateRoute(SignUpMethodType.email, email);
      },
    );
  }

  Future<void> onOAuthResult(
      Map<String, dynamic> result, SignUpMethodType type) async {
    final token = result['token'];
    if (token != null) {
      context.showLoadingDialog();
      final result = await ref
          .read(authNotifierProvider.notifier)
          .oAuthLoginCallback(token);
      result.fold(
        (failure) {
          context.hideLoadingDialog();
          context.showSnackBar(failure.localizedErrorMessage);
        },
        (response) {
          context.hideLoadingDialog();
          ref.read(homeNotifierProvider.notifier).updateUserData(response);
          appLogger.debug('Login Response: ${response.toString()}');
          Map<String, dynamic> tokenData = JwtDecoder.decode(token);
          ref.read(appSettingNotifierProvider.notifier)
            ..setOAuthToken(token)
            ..setEmail(tokenData['email'] ?? '')
            ..setUserLoggedIn(true);
          navigateRoute(type, response.legacyUserData.email);
        },
      );
    } else {
      context.showSnackBar('Failed to retrieve token');
    }
  }

  //Change Email flow

  void startChangeEmailFlow(String email) async {
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .startChangeEmail(email, widget.password!);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        AppDialog.errorDialog(
            context: context,
            title: 'error'.i18n,
            content: failure.localizedErrorMessage);
      },
      (newEmail) {
        context.hideLoadingDialog();
        appLogger.debug('Change email started successfully: $newEmail');
        navigateRoute(SignUpMethodType.email, email);
      },
    );
  }

  void navigateRoute(SignUpMethodType type, String email) {
    switch (type) {
      case SignUpMethodType.apple:
      case SignUpMethodType.google:
        if (PlatformUtils.isIOS) {
          AppDialog.showLanternProDialog(
            context: context,
            onPressed: () {
              appRouter.popUntilRoot();
            },
          );
          return;
        }
        appRouter
            .push(ChoosePaymentMethod(email: email, authFlow: AuthFlow.oauth));
        break;
      case SignUpMethodType.email:
        appRouter.push(ConfirmEmail(
            email: email,
            authFlow: widget.authFlow,
            password: widget.password));
        break;
      case SignUpMethodType.withoutEmail:
        continueWithoutEmail();
        break;
    }
  }

  void continueWithoutEmail() {
    showEmailDialog(() async {
      try {
        context.showLoadingDialog();
        await checkUserAccountStatus(ref, context);
        context.hideLoadingDialog();
        AppDialog.showLanternProDialog(
          context: context,
          onPressed: () {
            appRouter.popUntilRoot();
          },
        );
      } catch (e) {
        context.hideLoadingDialog();
        appLogger.error('Error while continuing without email: $e');
        context.showSnackBar('error_occurred'.i18n);
      }
    });
  }

  void showEmailDialog(OnPressed onContinue) {
    final size = MediaQuery.of(context).size;
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: size.width * 0.7,
              height: 40,
              child: AutoSizeText(
                'are_you_sure'.i18n,
                style: textTheme!.headlineMedium,
                maxLines: 1,
                minFontSize: 20,
                maxFontSize: 24,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          Text(
            'continue_without_email_message'.i18n,
            style: textTheme!.bodyMedium,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'continue'.i18n,
          textColor: AppColors.gray6,
          onPressed: () {
            appRouter.maybePop();
            Future.delayed(const Duration(milliseconds: 300), onContinue);
          },
        ),
        AppTextButton(
          label: 'add_email'.i18n,
          textColor: AppColors.blue6,
          onPressed: () {
            appRouter.maybePop();
          },
        )
      ],
    );
  }
}
