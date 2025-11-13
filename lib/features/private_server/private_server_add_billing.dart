import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'PrivateServerAddBilling')
class PrivateServerAddBilling extends HookConsumerWidget {
  const PrivateServerAddBilling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(privateServerNotifierProvider);
    final isContinueClicked = useState(false);

    useEffect(() {
      /// When there is only compartment, proceed to we dont need to show project details
      if (serverState.status == 'EventTypeOnlyCompartment') {
        context.hideLoadingDialog();
        appRouter.push(PrivateServerDetails(
            accounts: [],
            provider: CloudProvider.digitalOcean,
            isPreFilled: true));
      }

      /// We are getting multiple accounts, show account selection screen
      if (serverState.status == 'EventTypeAccounts') {
        context.hideLoadingDialog();
        final accounts = serverState.data!.split(', ');
        appRouter.push(PrivateServerDetails(
            accounts: accounts, provider: CloudProvider.digitalOcean));
      }

      /// Getting some error while validating session
      if (serverState.status == 'EventTypeValidationError') {
        if (isContinueClicked.value) {
          appLogger.error("Error validating session for private server.",
              serverState.error);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.hideLoadingDialog();
            appLogger.error(
                "Private server deployment failed.", serverState.error);
            AppDialog.errorDialog(
              context: context,
              title: 'error'.i18n,
              content: serverState.error!.toTitleCase(),
            );
          });
        }
      }
      return null;
    }, [serverState.status]);

    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'add_billing_details'.i18n,
      body: Column(
        children: <Widget>[
          InfoRow(text: 'do_billing_details_message'.i18n),
          SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.all(defaultSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SizedBox(height: defaultSize),
                Center(
                  child: AppImage(
                    path: AppImagePaths.creditCard,
                    color: AppColors.gray9,
                    height: 30,
                  ),
                ),

                SizedBox(height: defaultSize),
                Center(
                  child: Text(
                    'how_to_add_billing_details'.i18n,
                    style: textTheme.titleMedium,
                  ),
                ),
                SizedBox(height: defaultSize),
                RichText(
                  textAlign: TextAlign.left,
                  text: TextSpan(
                    style:
                        textTheme.bodyMedium!.copyWith(color: AppColors.gray8),
                    text: '${'1'.i18n}. ',
                    children: [
                      TextSpan(text: '${'tap'.i18n} '),
                      TextSpan(
                          text: '${'open_system_settings'.i18n} ',
                          style: AppTextStyles.bodyMediumBold!.copyWith(
                            color: AppColors.gray8,
                          )),
                      TextSpan(text: 'below_to_go_to_do'.i18n),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style:
                        textTheme.bodyMedium!.copyWith(color: AppColors.gray8),
                    text: '${'2'.i18n}. ',
                    children: [
                      TextSpan(text: '${'add_payment_method'.i18n} '),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style:
                        textTheme.bodyMedium!.copyWith(color: AppColors.gray8),
                    text: '${'3'.i18n}. ',
                    children: [
                      TextSpan(text: '${'return_to_lantern'.i18n} '),
                    ],
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
          Spacer(),
          PrimaryButton(
            isTaller: true,
            icon: AppImagePaths.outsideBrowser,
            iconColor: AppColors.white,
            label: 'open_system_settings'.i18n,
            onPressed: () {
              UrlUtils.openUrl(AppUrls.digitalOceanBillingUrl);
            },
          ),
          SizedBox(height: defaultSize),
          SecondaryButton(
              isTaller: true,
              label: 'continue'.i18n,
              onPressed: () {
                onContinueClicked(ref, context);
                isContinueClicked.value = true;
              })
        ],
      ),
    );
  }

  Future<void> onContinueClicked(WidgetRef ref, BuildContext context) async {
    try {
      context.showLoadingDialog();
      final result = await ref
          .read(privateServerNotifierProvider.notifier)
          .validateSession();
      result.fold(
        (f) {
          context.hideLoadingDialog();
          context.showSnackBar(f.localizedErrorMessage);
        },
        (_) {},
      );
    } catch (e) {
      appLogger.error("Error validating session: $e");
    }
  }
}
