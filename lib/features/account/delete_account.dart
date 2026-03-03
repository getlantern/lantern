import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/features/auth/add_email.dart';
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

  SignUpMethodType _resolveOAuthMethodType(String provider) {
    return SignUpMethodType.values.firstWhere(
      (e) => e.name == provider,
      orElse: () => SignUpMethodType.google,
    );
  }

  Widget _buildBody() {
    final textTheme = Theme.of(context).textTheme;
    final passwordController = useTextEditingController();
    final buttonEnabled = useState(false);
    final appSetting = ref.read(appSettingProvider);
    final isSSOUser = appSetting.oAuthToken.isNotEmpty;
    final oAuthMethodType =
        _resolveOAuthMethodType(appSetting.oAuthLoginProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: AppImage(
              path: AppImagePaths.delete,
              width: 120,
              height: 120,
              useThemeColor: false,
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
                color: context.textSecondary,
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              isSSOUser
                  ? 'confirm_with_account'
                      .i18n
                      .fill([appSetting.oAuthLoginProvider])
                  : 'delete_account_message_two'.i18n,
              style: textTheme.bodyLarge!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          if (!isSSOUser) ...{
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
          },
          SizedBox(height: size24),
          if (isSSOUser)
            OAuthLogin(
              methodType: oAuthMethodType,
              onResult: (payload) => processOAuthResult(payload),
            )
          else
            PrimaryButton(
              label: 'confirm_deletion'.i18n,
              enabled: buttonEnabled.value,
              bgColor: AppColors.red7,
              isTaller: true,
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

  void processOAuthResult(Map<String, dynamic> payload) {
    // No need to handle the token here since the user is already authenticated.
    // We just need to proceed with account deletion.
    appLogger.info('Received OAuth payload for account deletion: $payload');
    final token = payload['token'] as String? ?? '';
    final oldToken = ref.read(appSettingProvider).oAuthToken;
    if (token != oldToken) {
      context.showSnackBarError('oauth_different_account'.i18n);
      return;
    }
    onDeleteAccount('');
  }

  Future<void> onDeleteAccount(String password) async {
    context.showLoadingDialog();
    appLogger.info('Initiating account deletion');
    final localStorageService = sl<LocalStorageService>();
    final String email = localStorageService.getUser()!.legacyUserData.email;
    final appSetting = localStorageService.getAppSetting();
    final isSSOUser = appSetting?.oAuthToken.isNotEmpty ?? false;

    final result = await ref
        .read(authProvider.notifier)
        .deleteAccount(email, password, isSSOUser);

    result.fold(
      (failure) {
        appLogger
            .error('Account deletion failed: ${failure.localizedErrorMessage}');
        context.hideLoadingDialog();
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (userResponse) async {
        context.hideLoadingDialog();
        ref.read(appSettingProvider.notifier)
          ..setEmail("")
          ..setOAuthToken("", "")
          ..setUserLoggedIn(false);
        appLogger.info('Account deletion successful, clearing user data and navigating to root');
        ref.read(homeProvider.notifier).updateUserData(userResponse);
        appRouter.popUntilRoot();
      },
    );
  }
}
