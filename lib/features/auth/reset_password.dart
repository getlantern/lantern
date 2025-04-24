import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/email_tag.dart';
import 'package:lantern/core/widgets/password_criteria.dart';

@RoutePage(name: 'ResetPassword')
class ResetPassword extends HookWidget {
  final String email;

  const ResetPassword({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final obscureText = useState(false);
    useListenable(confirmPasswordController);
    return BaseScreen(
      title: 'reset_your_password'.i18n,
      body: Column(
        children: [
          SizedBox(height: defaultSize),
          Center(child: EmailTag(email: email)),
          SizedBox(height: defaultSize),
          AppTextField(
            hintText: '',
            label: 'create_new_password'.i18n,
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
              obscureText: obscureText.value,
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
              suffixIcon: _buildSuffix(obscureText)),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'reset_password'.i18n,
            enabled: (passwordController.text.isNotEmpty &&
                confirmPasswordController.text.isNotEmpty &&
                passwordController.text == confirmPasswordController.text &&
                confirmPasswordController.text.isPasswordValid()),
            onPressed: () {},
          ),
          SizedBox(height: 32),
          PasswordCriteriaWidget(textEditingController: passwordController)
        ],
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
}
