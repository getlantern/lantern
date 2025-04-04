import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'SignInPassword')
class SignInPassword extends StatelessWidget {
  final String email;

  const SignInPassword({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'welcome_to_lantern_pro'.i18n,
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          Center(child: _buildEmailTag()),
          SizedBox(height: defaultSize),
          AppTextField(
            hintText: '',
            prefixIcon: AppImagePaths.lock,
            label: 'enter_password'.i18n,
            obscureText: true,
            onChanged: (value) {},
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'continue'.i18n,
            onPressed: () {},
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: 32),
          AppTextButton(
            label: 'forgot_password'.i18n,
            textColor: AppColors.gray9,
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _buildEmailTag() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: AppColors.blue1,
        border: Border.all(
          width: 1,
          color: AppColors.gray3,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          AppImage(
            path: AppImagePaths.email,
          ),
          const SizedBox(width: 8),
          Text(email)
        ],
      ),
    );
  }
}
