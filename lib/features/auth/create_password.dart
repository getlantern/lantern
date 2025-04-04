import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/password_criteria.dart';

import '../../core/common/app_text_field.dart';

@RoutePage(name: 'CreatePassword')
class CreatePassword extends HookWidget {
  final String email;

  const CreatePassword({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final passwordTextController = useTextEditingController();
    return BaseScreen(
      title: 'create_password'.i18n,
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          _buildEmailTag(),
          SizedBox(height: defaultSize),
          AppTextField(
            controller: passwordTextController,
            hintText: '',
            prefixIcon: AppImagePaths.lock,
            label: "create_password".i18n,
            obscureText: true,
            onChanged: (value) {},
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'continue'.i18n,
            onPressed: () {
              appRouter.popUntilRoot();
            },
          ),
          SizedBox(height: defaultSize),
          PasswordCriteriaWidget(textEditingController: passwordTextController)
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
