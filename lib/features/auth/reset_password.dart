import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/email_tag.dart';
import 'package:lantern/core/widgets/password_criteria.dart';

@RoutePage(name: 'ResetPassword')
class ResetPassword extends StatefulWidget {
  final String email;

  const ResetPassword({
    super.key,
    required this.email,
  });

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscureText = false;

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'reset_your_password'.i18n,
      body: Column(
        children: [
          SizedBox(height: defaultSize),
          Center(child: EmailTag(email: widget.email)),
          SizedBox(height: defaultSize),
          AppTextField(
            hintText: '',
            label: 'create_new_password'.i18n,
            obscureText: obscureText,
            controller: passwordController,
            prefixIcon: AppImagePaths.lock,
            onChanged: (value) {
              setState(() {});
            },
            suffixIcon: _buildSuffix(),
          ),
          SizedBox(height: 20),
          AppTextField(
              hintText: '',
              label: 'confirm_new_password'.i18n,
              obscureText: obscureText,
              controller: confirmPasswordController,
              prefixIcon: AppImagePaths.lock,
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value!.isEmpty) {
                  return "confirm_password_required".i18n;
                }
                if (value != passwordController.text) {
                  return "passwords_do_not_match".i18n;
                }
                return null;
              },
              suffixIcon: _buildSuffix()),
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

  Widget _buildSuffix() {
    return AppImage(
      color: AppColors.yellow9,
      path: obscureText ? AppImagePaths.eyeHide : AppImagePaths.eye,
      onPressed: () {
        setState(() {
          obscureText = !obscureText;
        });
      },
    );
  }
}
