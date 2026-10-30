import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';

import '../../core/common/common.dart';

@RoutePage(name: 'ResetPasswordEmail')
class ResetPasswordEmail extends HookConsumerWidget {
  final String? email;

  const ResetPasswordEmail({super.key, this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController(
      text: isLegacyPlaceholderEmail(email ?? '') ? '' : email,
    );
    useListenable(emailController);
    return EnterKeyShortcut(
      onEnter: () {
        if (_canRecover(emailController.text)) {
          onNext(context, emailController.text, ref);
        }
      },
      child: BaseScreen(
        title: 'reset_your_password'.i18n,
        body: Column(
          children: <Widget>[
            SizedBox(height: defaultSize),
            Text(
              'enter_your_lantern_pro_account_email'.i18n,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: defaultSize),
            AppTextField(
              fieldKey: AuthKeys.resetPasswordEmailField,
              hintText: '',
              controller: emailController,
              maxLines: 1,
              prefixIcon: AppImagePaths.email,
              label: 'email'.i18n,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              onSubmitted: (_) => onNext(context, emailController.text, ref),
              validator: (value) {
                if (value!.isEmpty) {
                  return null;
                }
                if (value.isNotEmpty) {
                  if (!_canRecover(value)) {
                    return 'invalid_email'.i18n;
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 32),
            PrimaryButton(
              key: AuthKeys.resetPasswordEmailNextButton,
              label: 'next'.i18n,
              isTaller: true,
              enabled: _canRecover(emailController.text),
              onPressed: () => onNext(context, emailController.text, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> onNext(BuildContext context, String email, WidgetRef ref) async {
    final trimmedEmail = email.trim();
    if (!_canRecover(trimmedEmail)) {
      context.showSnackBarError('invalid_email'.i18n);
      return;
    }
    context.showLoadingDialog();
    final result = await ref
        .read(authProvider.notifier)
        .startRecoveryByEmail(trimmedEmail);
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        appRouter.push(
          ConfirmEmail(email: trimmedEmail, authFlow: AuthFlow.resetPassword),
        );
      },
    );
  }

  bool _canRecover(String email) =>
      email.trim().isValidEmail() && !isLegacyPlaceholderEmail(email);
}
