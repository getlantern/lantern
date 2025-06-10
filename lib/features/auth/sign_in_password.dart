import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/email_tag.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

@RoutePage(name: 'SignInPassword')
class SignInPassword extends HookConsumerWidget {
  final String email;

  const SignInPassword({super.key, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passwordController = useTextEditingController();
    final obscureText = useState(true);

    useListenable(passwordController);
    return BaseScreen(
      title: 'welcome_to_lantern_pro'.i18n,
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          Center(child: EmailTag(email: email)),
          SizedBox(height: defaultSize),
          AppTextField(
            hintText: '',
            controller: passwordController,
            prefixIcon: AppImagePaths.lock,
            label: 'enter_password'.i18n,
            obscureText: obscureText.value,
            suffixIcon: _buildSuffix(obscureText),
            onChanged: (value) {},
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'continue'.i18n,
            enabled: passwordController.text.isNotEmpty,
            onPressed: () => signInWithPassword(
                context, ref, passwordController.text.trim()),
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: 32),
          AppTextButton(
            label: 'forgot_password'.i18n,
            textColor: AppColors.gray9,
            onPressed: () {
              appRouter.push(ResetPasswordEmail(email: email));
            },
          )
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



  Future<void> signInWithPassword(
    BuildContext context,
    WidgetRef ref,
    String password,
  ) async {
    hideKeyboard();
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(email, password);
    result.fold(
      (error) {
        context.hideLoadingDialog();
        AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: error.localizedErrorMessage,
        );
      },
      (user) {
        context.hideLoadingDialog();
        if (!user.success) {
          // Login has failed
          // start device flow
          appLogger.warning("Login failed for user: $email, starting device flow");
          startDeviceFlow();
        }
        //login successfully
        ref.read(appSettingNotifierProvider.notifier)
          ..setUserLoggedIn(true)
          ..setEmail(email);
        ref.read(homeNotifierProvider.notifier).updateUserData(user);
        appRouter.popUntilRoot();
      },
    );
  }

  void startDeviceFlow() {
    // Implement the logic to start the device flow
    // This could involve navigating to a specific screen or showing a dialog
    // appRouter.push(const DeviceFlowScreen());
  }
}
