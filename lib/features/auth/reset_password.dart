import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/email_tag.dart';
import 'package:lantern/core/widgets/password_criteria.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';

@RoutePage(name: 'ResetPassword')
class ResetPassword extends HookConsumerWidget {
  final String email;
  final String code;

  const ResetPassword({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final obscureText = useState(true);
    useListenable(passwordController);
    useListenable(confirmPasswordController);
    return BaseScreen(
      title: 'reset_your_password'.i18n,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: defaultSize),
            Center(child: EmailTag(email: email)),
            SizedBox(height: defaultSize),
            AppTextField(
              hintText: '',
              label: 'create_new_password'.i18n,
              keyboardType: TextInputType.visiblePassword,
              enableSuggestions: false,
              autocorrect: false,
              obscureText: obscureText.value,
              controller: passwordController,
              prefixIcon: AppImagePaths.lock,
              onChanged: (value) {},
              suffixIcon: _buildSuffix(obscureText),
            ),
            SizedBox(height: 20),
            AppTextField(
              hintText: '',
              label: 'confirm_new_password'.i18n,
              keyboardType: TextInputType.visiblePassword,
              obscureText: obscureText.value,
              enableSuggestions: false,
              autocorrect: false,
              controller: confirmPasswordController,
              prefixIcon: AppImagePaths.lock,
              onChanged: (value) {},
              validator: (value) {
                if (value!.isEmpty) {
                  return "confirm_password_required".i18n;
                }
                if (value != passwordController.text) {
                  return "passwords_do_not_match".i18n;
                }
                return null;
              },
              suffixIcon: _buildSuffix(obscureText),
            ),
            SizedBox(height: 32),
            PrimaryButton(
                label: 'reset_password'.i18n,
                isTaller: true,
                enabled: (passwordController.text.isNotEmpty &&
                    confirmPasswordController.text.isNotEmpty &&
                    passwordController.text == confirmPasswordController.text &&
                    confirmPasswordController.text.isPasswordValid()),
                onPressed: () => onResetPasswordTap(
                    context, confirmPasswordController.text, ref)),
            SizedBox(height: 32),
            PasswordCriteriaWidget(textEditingController: passwordController)
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

  Future<void> onResetPasswordTap(
      BuildContext context, String password, WidgetRef ref) async {
    context.showLoadingDialog();

    final result = await ref
        .read(authProvider.notifier)
        .completeRecoveryByEmail(email, password, code);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        AppDialog.customDialog(
          context: context,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 24),
              Text('password_has_been_updated'.i18n,
                  style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(height: 16),
              Text('password_has_been_updated_message'.i18n,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          action: [
            AppTextButton(
              label: 'continue'.i18n,
              textColor: AppColors.gray7,
              onPressed: () {
                appRouter.popUntilRoot();
              },
            ),
            AppTextButton(
              label: 'sign_in'.i18n,
              onPressed: () {
                appRouter.pushAndPopUntil(SignInEmail(),
                    predicate: (route) => route.isFirst);
              },
            )
          ],
        );
      },
    );
  }
}
