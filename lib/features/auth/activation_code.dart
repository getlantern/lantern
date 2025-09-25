import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/reseller_formatter.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

@RoutePage(name: 'ActivationCode')
class ActivationCode extends HookConsumerWidget {
  final String email;
  final String code;

  const ActivationCode({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final validCode = useState(false);
    return BaseScreen(
      title: 'Enter Activation Code',
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          AppTextField(
            maxLength: 29,
            hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
            controller: codeController,
            prefixIcon: AppImagePaths.lock,
            label: 'activation_code'.i18n,
            inputFormatters: [
              ResellerCodeFormatter(),
            ],
            validator: (value) {
              if (value!.isEmpty) {
                return 'activation_code_required'.i18n;
              }
              if (!RegExp(r'^[a-zA-Z0-9-]*$').hasMatch(value)) {
                return 'invalid_activation_code'.i18n;
              }
              if (value.replaceAll('-', '').length != 25) {
                return 'invalid_activation_code_length'.i18n;
              }
              return null;
            },
            onChanged: (value) {
              if (RegExp(r'^[a-zA-Z0-9-]*$').hasMatch(value) &&
                  value.replaceAll('-', '').length == 25) {
                validCode.value = true;
              } else {
                validCode.value = false;
              }
            },
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'activate_lantern_pro'.i18n,
            enabled: validCode.value,
            isTaller: true,
            onPressed: () => onActivatePro(codeController.text, ref, context),
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }

  Future<void> onActivatePro(
      String resellerCode, WidgetRef ref, BuildContext context) async {
    appLogger.info('Activation code entered: $resellerCode');

    context.showLoadingDialog();
    final result = await ref
        .read(lanternServiceProvider)
        .activationCode(email: email, resellerCode: resellerCode);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        appLogger.error('Activation code failed: $failure');
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        appLogger.info('Activation code successful');

        checkUserAccountStatus(ref, context);
        context.pushRoute(CreatePassword(
            email: email, authFlow: AuthFlow.activationCode, code: code));
      },
    );
  }
}
