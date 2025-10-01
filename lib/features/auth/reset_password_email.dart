import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';

import '../../core/common/common.dart';

@RoutePage(name: 'ResetPasswordEmail')
class ResetPasswordEmail extends HookConsumerWidget {
  final String? email;

  const ResetPasswordEmail({
    super.key,
    this.email,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController(text: email);
    return BaseScreen(
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
            hintText: '',
            controller: emailController,
            maxLines: 1,
            prefixIcon: AppImagePaths.email,
            label: 'email'.i18n,
            validator: (value) {
              if (value!.isEmpty) {
                return null;
              }
              if (value.isNotEmpty) {
                if (!value.isValidEmail()) {
                  return 'invalid_email'.i18n;
                }
              }
              return null;
            },
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'next'.i18n,
            isTaller: true,
            onPressed: () => onNext(context, emailController.text, ref),
          ),
        ],
      ),
    );
  }

  Future<void> onNext(BuildContext context, String email, WidgetRef ref) async {
    if (!email.isValidEmail()) {
      context.showSnackBarError('invalid_email'.i18n);
      return;
    }
    context.showLoadingDialog();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .startRecoveryByEmail(email);
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        appRouter
            .push(ConfirmEmail(email: email, authFlow: AuthFlow.resetPassword));
      },
    );
  }
}
