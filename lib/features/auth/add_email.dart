import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/jwt_utils.dart';
import 'package:lantern/features/auth/provider/oauth_notifier.dart';

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
              SecondaryButton(
                label: 'continue_with_google'.i18n,
                icon: AppImagePaths.google,
                onPressed: () => onContinueTap(SignUpMethodType.google),
              ),
              SizedBox(height: defaultSize),
              SecondaryButton(
                label: 'continue_with_apple'.i18n,
                icon: AppImagePaths.apple,
                onPressed: () => onContinueTap(SignUpMethodType.apple),
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
      appRouter.push(ConfirmEmail(email: email, authFlow: widget.authFlow));
    }
    if (type == SignUpMethodType.google || type == SignUpMethodType.apple) {
      oAuthLogin(type);
    }
  }

  Future<void> oAuthLogin(SignUpMethodType type) async {
    context.showLoadingDialog();
    final result =
        await ref.read(oAuthNotifierProvider.notifier).oAuthLogin(type.name);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (url) async {
        context.hideLoadingDialog();
        appLogger.debug('OAuth URL: $url');

        UrlUtils.openWebview<Map<String, dynamic>>(
          url,
          title: type.name.capitalize,
          onWebviewResult: (result) {
            // User has successfully logged in to google or apple
            final map = result;
            final token = map['token'];
            // Decode the token and get the email
            final data = JwtToken.decodeToken(token);


          },
        );
      },
    );
  }

  void navigateAuth() {
    switch (widget.authFlow) {
      case AuthFlow.resetPassword:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AuthFlow.signUp:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AuthFlow.activationCode:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void postPaymentNavigate(SignUpMethodType type) {
    switch (type) {
      case SignUpMethodType.email:
        // appRouter.push(ConfirmEmail(email: emailController.text));
        break;
      case SignUpMethodType.google:
        break;
      case SignUpMethodType.apple:
        break;
      case SignUpMethodType.withoutEmail:
        appRouter.popUntilRoot();
        break;
    }
  }
}
