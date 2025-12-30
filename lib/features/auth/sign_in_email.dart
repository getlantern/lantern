import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/features/auth/add_email.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

import '../../core/common/common.dart';

@RoutePage(name: 'SignInEmail')
class SignInEmail extends HookConsumerWidget {
  const SignInEmail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    useListenable(emailController);
    return EnterKeyShortcut(
      onEnter: () {
        if (emailController.text.isValidEmail()) {
          appRouter.push(SignInPassword(email: emailController.text));
          return;
        }
      },
      child: BaseScreen(
        title: 'sign_in_to_lantern_pro'.i18n,
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SizedBox(height: defaultSize),
              Text(
                'enter_your_lantern_pro_account_details'.i18n,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: defaultSize),
              AppTextField(
                hintText: '',
                prefixIcon: AppImagePaths.email,
                label: 'email'.i18n,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    signInWithEmail(emailController.text, context),
                keyboardType: TextInputType.emailAddress,
                controller: emailController,
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
                onChanged: (value) {},
              ),
              SizedBox(height: 32),
              PrimaryButton(
                label: 'sign_in_with_email'.i18n,
                enabled: emailController.text.isValidEmail(),
                onPressed: () => signInWithEmail(emailController.text, context),
                isTaller: true,
              ),
              SizedBox(height: defaultSize),
              DividerSpace(),
              SizedBox(height: defaultSize),
              OAuthLogin(
                methodType: SignUpMethodType.google,
                onResult: (token) => onOAuthResult(token, context, ref),
              ),
              SizedBox(height: defaultSize),
              OAuthLogin(
                methodType: SignUpMethodType.apple,
                onResult: (token) => onOAuthResult(token, context, ref),
              ),
              SizedBox(height: defaultSize),
              DividerSpace(),
              SizedBox(height: 32),
              AppRichText(
                texts: '${'new_to_lantern_pro'.i18n} ',
                boldTexts: 'create_an_account'.i18n,
                boldUnderline: true,
                boldOnPressed: () {
                  appRouter.push(Plans());
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  void signInWithEmail(
    String email,
    BuildContext context,
  ) {
    if (!email.isValidEmail()) {
      context.showSnackBarError('invalid_email'.i18n);
      return;
    }
    appRouter.push(SignInPassword(email: email));
  }

  Future<void> onOAuthResult(
      Map<String, dynamic> result, BuildContext context, WidgetRef ref) async {
    final token = result['token'];
    if (token != null) {
      context.showLoadingDialog();
      final result =
          await ref.read(authProvider.notifier).oAuthLoginCallback(token);
      result.fold(
        (failure) {
          context.hideLoadingDialog();
          context.showSnackBar(failure.localizedErrorMessage);
        },
        (response) {
          context.hideLoadingDialog();
          ref.read(homeProvider.notifier).updateUserData(response);
          appLogger.debug('Login Response: ${response.toString()}');
          Map<String, dynamic> tokenData = JwtDecoder.decode(token);
          ref.read(appSettingProvider.notifier)
            ..setOAuthToken(token)
            ..setEmail(tokenData['email'] ?? '')
            ..setUserLoggedIn(true);

          appRouter.popUntilRoot();
        },
      );
    } else {
      context.showSnackBar('Failed to retrieve token');
    }
  }
}
