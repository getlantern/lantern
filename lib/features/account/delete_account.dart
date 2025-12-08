import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

import '../../core/common/common.dart';
import '../../core/services/injection_container.dart';
import '../auth/provider/auth_notifier.dart';

@RoutePage(name: 'DeleteAccount')
class DeleteAccount extends StatefulHookConsumerWidget {
  const DeleteAccount({super.key});

  @override
  _DeleteAccountState createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<DeleteAccount> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'delete_account'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    final textTheme = Theme.of(context).textTheme;
    final passwordController = useTextEditingController();
    final buttonEnabled = useState(false);
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
            controller: passwordController,
            prefixIcon: AppImagePaths.lock,
            onChanged: (value) {
              buttonEnabled.value = value.isNotEmpty;
            },
          ),
          SizedBox(height: size24),
          PrimaryButton(
            label: 'confirm_deletion'.i18n,
            enabled: buttonEnabled.value,
            bgColor: AppColors.red7,
            onPressed: () => onDeleteAccount(passwordController.text),
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

  Future<void> onDeleteAccount(String password) async {
    context.showLoadingDialog();
    final String email =
        sl<LocalStorageService>().getUser()!.legacyUserData.email;
    final result =
        await ref.read(authProvider.notifier).deleteAccount(email, password);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (userResponse) async {
        context.hideLoadingDialog();
        ref.read(appSettingProvider.notifier)
          ..setEmail("")
          ..setOAuthToken("")
          ..setUserLoggedIn(false);

        ref.read(homeProvider.notifier).updateUserData(userResponse);
        appRouter.popUntilRoot();
      },
    );
  }
}
