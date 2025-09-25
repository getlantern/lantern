import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/email_tag.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

@RoutePage(name: 'SignInPassword')
class SignInPassword extends StatefulHookConsumerWidget {
  final String email;
  final bool fromChangeEmail;

  const SignInPassword(
      {super.key, required this.email, this.fromChangeEmail = false});

  @override
  ConsumerState createState() => _SignInPasswordState();
}

class _SignInPasswordState extends ConsumerState<SignInPassword> {
  @override
  Widget build(BuildContext context) {
    final passwordController = useTextEditingController();
    final obscureText = useState(true);

    useListenable(passwordController);
    return BaseScreen(
      title: widget.fromChangeEmail
          ? 'change_email'.i18n
          : 'welcome_to_lantern_pro'.i18n,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            SizedBox(height: defaultSize),
            Center(child: EmailTag(email: widget.email)),
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
            SizedBox(height: 16),
            if (widget.fromChangeEmail)
              Text('confirm_password_to_continue'.i18n,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: AppColors.gray8,
                      )),
            SizedBox(height: 32),
            PrimaryButton(
              label: 'continue'.i18n,
              enabled: passwordController.text.isNotEmpty,
              isTaller: true,
              onPressed: () =>
                  signInWithPassword(passwordController.text.trim()),
            ),
            SizedBox(height: defaultSize),
            DividerSpace(),
            SizedBox(height: 32),
            AppTextButton(
              label: 'forgot_password'.i18n,
              textColor: AppColors.gray9,
              onPressed: () {
                appRouter.push(ResetPasswordEmail(email: widget.email));
              },
            )
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

  Future<void> signInWithPassword(String password) async {
    hideKeyboard();
    if (widget.fromChangeEmail) {
      /// If the user is changing email, we need to verify the password
      context.pushRoute(
          AddEmail(authFlow: AuthFlow.changeEmail, password: password));
      return;
    }
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(widget.email, password);
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
          // Login has failed reason being user has reached device limit
          // start device flow
          appLogger.warning(
              "Login failed for user: ${widget.email}, starting device flow");
          startDeviceFlow(user.devices.toList(), password, context);
          return;
        }
        //login successfully
        ref.read(appSettingNotifierProvider.notifier)
          ..setUserLoggedIn(true)
          ..setEmail(widget.email);
        ref.read(homeNotifierProvider.notifier).updateUserData(user);
        appRouter.popUntilRoot();
      },
    );
  }

  void startDeviceFlow(List<UserResponse_Device> devices, String password,
      BuildContext context) {
    appRouter.push(DeviceLimitReached(devices: devices)).then(
      (value) {
        if (value != null && value is bool) {
          /// If a device was selected, remove it and now sign in
          signInWithPassword(password);
        }
      },
    );
  }
}
