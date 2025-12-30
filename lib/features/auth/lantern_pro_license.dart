import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/formatter.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

@RoutePage(name: 'LanternProLicense')
class LanternProLicense extends HookConsumerWidget {
  final String email;
  final String code;

  const LanternProLicense({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final validCode = useState(false);
    final normalizedLen = useState<int>(0);

    void syncFromText(String text) {
      final cleanedLen = text.replaceAll('-', '').length;
      normalizedLen.value = cleanedLen;
      validCode.value =
          RegExp(r'^[A-Z0-9-]*$').hasMatch(text) && cleanedLen == 25;
    }

    return EnterKeyShortcut(
      onEnter: () {
        if (validCode.value) {
          onActivatePro(codeController.text, ref, context);
        }
      },
      child: BaseScreen(
        title: 'lantern_pro_license'.i18n,
        body: Column(
          children: <Widget>[
            SizedBox(height: defaultSize),
            AppTextField(
              maxLength: 29,
              hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
              controller: codeController,
              prefixIcon: AppImagePaths.lock,
              label: 'lantern_pro_license'.i18n,
              inputFormatters: [
                ResellerCodeFormatter(),
                UpperCaseTextFormatter(),
              ],
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) {
                  return 'lantern_pro_license_required'.i18n;
                }

                if (!RegExp(r'^[A-Z0-9-]*$').hasMatch(v)) {
                  return 'lantern_pro_license_invalid'.i18n;
                }

                if (v.replaceAll('-', '').length != 25) {
                  return 'lantern_pro_license_invalid_length'.i18n;
                }

                return null;
              },
              onChanged: (value) => syncFromText(value),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${normalizedLen.value}/25',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gray6,
                      ),
                ),
              ),
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
      ),
    );
  }

  Future<void> onActivatePro(
      String resellerCode, WidgetRef ref, BuildContext context) async {
    final maskedCode = resellerCode.length > 4
        ? '***${resellerCode.substring(resellerCode.length - 4)}'
        : '***';
    appLogger.info('Lantern Pro license entered (masked): $maskedCode');

    context.showLoadingDialog();
    final result = await ref
        .read(lanternServiceProvider)
        .activationCode(email: email, resellerCode: resellerCode);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        appLogger.error('Lantern Pro license activation failed: $failure');
        context.showSnackBarError(failure.localizedErrorMessage);
      },
      (_) async {
        appLogger.info('Lantern Pro license activation successful');
        await checkUserAccountStatus(ref, context);
        context.hideLoadingDialog();

        if (code.isEmpty) {
          appLogger
              .info('No code provided, user is using OAuth (skip password)');
          AppDialog.showLanternProDialog(
            context: context,
            onPressed: () => appRouter.popUntilRoot(),
          );
          return;
        }

        context.pushRoute(
          CreatePassword(
            email: email,
            authFlow: AuthFlow.lanternProLicense,
            code: code,
          ),
        );
      },
    );
  }
}
