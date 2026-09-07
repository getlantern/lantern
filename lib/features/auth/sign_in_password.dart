import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/widgets/email_tag.dart';
import 'package:lantern/features/auth/device_limit_flow.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

@RoutePage(name: 'SignInPassword')
class SignInPassword extends StatefulHookConsumerWidget {
  final String email;
  final bool fromChangeEmail;

  const SignInPassword({
    super.key,
    required this.email,
    this.fromChangeEmail = false,
  });

  @override
  ConsumerState createState() => _SignInPasswordState();
}

class _SignInPasswordState extends ConsumerState<SignInPassword> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final passwordController = useTextEditingController();
    final obscureText = useState(true);

    useListenable(passwordController);
    return EnterKeyShortcut(
      onEnter: () {
        if (passwordController.text.isNotEmpty) {
          signInWithPassword(passwordController.text.trim());
        }
      },
      child: BaseScreen(
        title: widget.fromChangeEmail
            ? 'change_email'.i18n
            : 'welcome_to_lantern'.i18n,
        body: AutofillGroup(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                SizedBox(height: defaultSize),
                Center(child: EmailTag(email: widget.email)),
                SizedBox(height: defaultSize),
                AppTextField(
                  fieldKey: AuthKeys.signInPasswordField,
                  hintText: '',
                  controller: passwordController,
                  autofocus: true,
                  autofillHints: const [AutofillHints.password],
                  keyboardType: TextInputType.visiblePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  prefixIcon: AppImagePaths.lock,
                  label: 'enter_password'.i18n,
                  obscureText: obscureText.value,
                  suffixIcon: _buildSuffix(obscureText),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    if (passwordController.text.isEmpty) return;
                    signInWithPassword(passwordController.text.trim());
                  },
                  onChanged: (value) {},
                ),
                SizedBox(height: 8),
                if (!widget.fromChangeEmail)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: defaultSize,
                    ),
                    child: Text(
                      'if_you_have_not_set_password'.i18n,
                      textAlign: TextAlign.start,
                      style: textTheme.labelMedium!.copyWith(
                        color: context.textDisabled,
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                if (widget.fromChangeEmail)
                  Text(
                    'confirm_password_to_continue'.i18n,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                SizedBox(height: 32),
                PrimaryButton(
                  key: AuthKeys.signInPasswordContinueButton,
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
                  key: AuthKeys.signInForgotPasswordButton,
                  label: 'forgot_password'.i18n,
                  textColor: context.textPrimary,
                  onPressed: () {
                    appRouter.push(ResetPasswordEmail(email: widget.email));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuffix(ValueNotifier<bool> obscureText) {
    return AppImage(
      color: context.textPrimary,
      path: obscureText.value ? AppImagePaths.eyeHide : AppImagePaths.eye,
      onPressed: () {
        obscureText.value = !obscureText.value;
      },
    );
  }

  Future<void> signInWithPassword(String password) async {
    hideKeyboard();
    if (widget.fromChangeEmail) {
      await verifyPasswordForChangeEmail(password);
      return;
    }
    context.showLoadingDialog();
    final result = await ref
        .read(authProvider.notifier)
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
          /// Login has failed reason being user has reached device limit
          /// start device flow
          appLogger.warning(
            "Login failed for user: ${widget.email}, starting device flow",
          );
          startDeviceFlow(user.devices.toList(), password, context);
          return;
        }

        ///login successfully
        TextInput.finishAutofillContext(shouldSave: true);

        /// save login state and user email
        /// update user data in home notifier
        /// fetch available servers
        ref.read(appSettingProvider.notifier).setUserLoggedIn(true);
        ref.read(homeProvider.notifier).updateUserData(user);
        appRouter.popUntilRoot();
      },
    );
  }

  /// Change-email flow: verify the current password against the backend before
  /// letting the user proceed to enter a new email. Only on success do we
  /// navigate to [AddEmail], carrying the verified password forward so the
  /// downstream startChangeEmail call can reuse it.
  Future<void> verifyPasswordForChangeEmail(String password) async {
    final loadingOverlay = context.loaderOverlay;
    loadingOverlay.show();
    final result = await ref
        .read(authProvider.notifier)
        .verifyPassword(widget.email, password);
    loadingOverlay.hide();
    if (!mounted) return;
    result.fold(
      (error) {
        AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: error.localizedErrorMessage,
        );
      },
      (_) {
        context.pushRoute(
          AddEmail(authFlow: AuthFlow.changeEmail, password: password),
        );
      },
    );
  }

  void startDeviceFlow(
    List<DeviceModel> devices,
    String password,
    BuildContext context,
  ) {
    startDeviceLimitFlow(devices, () async {
      if (!mounted) return;
      signInWithPassword(password);
    });
  }
}
