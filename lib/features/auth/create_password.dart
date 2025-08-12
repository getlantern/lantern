import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/email_tag.dart';
import 'package:lantern/core/widgets/password_criteria.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';

@RoutePage(name: 'CreatePassword')
class CreatePassword extends HookConsumerWidget {
  final String email;
  final String code;
  final AuthFlow authFlow;

  const CreatePassword({
    super.key,
    required this.email,
    required this.authFlow,
    required this.code,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passwordTextController = useTextEditingController();
    final obscureText = useState(true);
    final isValidPassword = useState(false);
    return BaseScreen(
      title: 'create_password'.i18n,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            SizedBox(height: defaultSize),
            EmailTag(email: email),
            SizedBox(height: defaultSize),
            AppTextField(
              controller: passwordTextController,
              hintText: '',
              prefixIcon: AppImagePaths.lock,
              label: "create_password".i18n,
              suffixIcon: _buildSuffix(obscureText),
              obscureText: obscureText.value,
              onChanged: (value) {
                isValidPassword.value = value.isPasswordValid();
              },
            ),
            SizedBox(height: 32),
            PrimaryButton(
              label: 'continue'.i18n,
              enabled: passwordTextController.text.isPasswordValid(),
              onPressed: () =>
                  onContinue(ref, passwordTextController.text, context),
            ),
            SizedBox(height: 32.0),
            PasswordCriteriaWidget(
                textEditingController: passwordTextController)
          ],
        ),
      ),
    );
  }

  Widget _buildSuffix(ValueNotifier<bool> obscureText) {
    return AppImage(
      color: AppColors.yellow9,
      path: obscureText.value ? AppImagePaths.eyeHide : AppImagePaths.eye,
      onPressed: () {
        obscureText.value = !obscureText.value;
      },
    );
  }

  Future<void> onContinue(
      WidgetRef ref, String password, BuildContext context) async {
    hideKeyboard();
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .completeChangeEmail(email, password, code);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        appLogger.error(
            'Failed to create password: ${failure.localizedErrorMessage}');
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (success) {
        context.hideLoadingDialog();
        appLogger.info('Password created successfully');
        resolveRoutes(context, ref);
      },
    );
  }

  Future<void> resolveRoutes(BuildContext context, WidgetRef ref) async {
    if (isStoreVersion()) {
      //We need call get user details here by then user has made payment
      context.showLoadingDialog();
      await checkUserAccountStatus(ref, context);
      context.hideLoadingDialog();
    }
    AppDialog.showLanternProDialog(
      context: context,
      onPressed: () {
        appRouter.popUntilRoot();
      },
    );
  }
}
