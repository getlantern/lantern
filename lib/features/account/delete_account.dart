import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_field.dart';
import '../../core/common/common.dart';

@RoutePage(name: 'DeleteAccount')
class DeleteAccount extends StatefulWidget {
  const DeleteAccount({super.key});

  @override
  _DeleteAccountState createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'delete_account'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: AppImage(
              path: AppImagePaths.delete,
              width: 120,
              height: 120,
            ),
          ),
          SizedBox(height: defaultSize),
          Center(
              child: Text('delete_account_?'.i18n,
                  style: textTheme.headlineSmall)),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'delete_account_message'.i18n,
              style: textTheme.bodyLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'delete_account_message_two'.i18n,
              style: textTheme.bodyLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          AppTextField(
            hintText: '',
            label: 'enter_password_to_confirm'.i18n,
            obscureText: true,
            prefixIcon: AppImagePaths.lock,
            onChanged: (value) {},
          ),
          SizedBox(height: size24),
          PrimaryButton(
            label: 'confirm_deletion'.i18n,
            enabled: false,
            bgColor: AppColors.red7,
            onPressed: () {},
          ),
          SizedBox(height: defaultSize),
          SecondaryButton(
            label: 'cancel'.i18n,
            onPressed: () {
              appRouter.maybePop();
            },
          ),
        ],
      ),
    );
  }
}
