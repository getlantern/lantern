import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/models/user.dart';

bool hasRegisteredProAccount(UserResponseModel? user) {
  final userData = user?.legacyUserData;
  return userData != null && userData.isPro && userData.unpassRegistered;
}

bool shouldShowProAccountSetupDialog({
  required UserResponseModel user,
  required bool userLoggedIn,
}) {
  final userData = user.legacyUserData;
  return userData.isPro && !userLoggedIn && !userData.unpassRegistered;
}

Future<void> openAccountOrProAccountSetup({
  required BuildContext context,
  required UserResponseModel user,
  required bool userLoggedIn,
}) async {
  final userData = user.legacyUserData;
  if (shouldShowProAccountSetupDialog(user: user, userLoggedIn: userLoggedIn)) {
    await showProAccountFlowDialog(
      context: context,
      hasEmail: userData.email.isNotEmpty,
    );
    return;
  }

  appRouter.push(Account());
}

Future<void> showProAccountFlowDialog({
  required BuildContext context,
  required bool hasEmail,
}) async {
  return AppDialog.customDialog(
    context: context,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 24.0),
        const AppImage(path: AppImagePaths.personAdd),
        const SizedBox(height: 16.0),
        Text(
          hasEmail ? 'set_account_password'.i18n : 'update_pro_account'.i18n,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: defaultSize),
        Text(
          hasEmail
              ? 'set_account_password_message'.i18n
              : 'update_pro_account_message'.i18n,
          style: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(color: context.textSecondary),
        ),
      ],
    ),
    action: [
      AppTextButton(
        label: 'cancel'.i18n,
        textColor: context.textDisabled,
        onPressed: () => appRouter.maybePop(),
      ),
      AppTextButton(
        label: hasEmail ? 'set_password'.i18n : 'add_email'.i18n,
        onPressed: () =>
            appRouter.popAndPush(AddEmail(authFlow: AuthFlow.signUp)),
      ),
    ],
  );
}
