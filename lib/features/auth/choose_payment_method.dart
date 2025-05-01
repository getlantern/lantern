import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/stripe_service.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/logs_path.dart';
import 'package:lantern/features/auth/provider/payment_notifier.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';

@RoutePage(name: 'ChoosePaymentMethod')
class ChoosePaymentMethod extends HookConsumerWidget {
  final String email;
  final AuthFlow authFlow;

  const ChoosePaymentMethod({
    super.key,
    required this.email,
    required this.authFlow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPlan =
        ref.watch(plansNotifierProvider.notifier).getSelectedPlan();
    final planData = ref.watch(plansNotifierProvider.notifier).getPlanData();
    return BaseScreen(
      title: 'choose_payment_method'.i18n,
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          InfoRow(
            imagePath: AppImagePaths.security,
            text: 'payment_information_encrypted'.i18n,
            onPressed: () {},
          ),
          SizedBox(height: defaultSize),
          PaymentCheckoutMethods(
            providers: PlatformUtils.isAndroid
                ? planData.providers.android
                : planData.providers.desktop,
            userPlan: userPlan,
            onSubscribe: (provider) => onSubscribe(provider, ref, context),
          )
        ],
      ),
    );
  }

  Future<void> onSubscribe(
      Android provider, WidgetRef ref, BuildContext context) async {
    if (PlatformUtils.isDesktop) {
      desktopPurchaseFlow(provider, ref, context);
      return;
    }

    /// only android side load version should be here
    androidStripeSubscription(provider, ref, context);
  }

  Future<void> androidStripeSubscription(
      Android provider, WidgetRef ref, BuildContext context) async {
    final userPlan = ref.read(plansNotifierProvider.notifier).getSelectedPlan();
    final paymentProvider = ref.read(paymentNotifierProvider.notifier);
    context.showLoadingDialog();

    ///get stripe details
    final result = await paymentProvider.stipeSubscription(userPlan.id);
    result.fold(
      (error) {
        context.showSnackBarError(error.localizedErrorMessage);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
      (stripeData) async {
        // Handle success
        context.hideLoadingDialog();

        /// Start stripe SDK
        sl<StripeService>().startStripeSubscription(
          options: StripeOptions.fromJson(stripeData),
          onSuccess: () {
            /// Subscription successful
            AppDialog.showLanternProDialog(context: context);
          },
          onError: (error) {
            ///error while subscribing
            context.showSnackBarError('purchase_not_completed'.i18n);
          },
        );
      },
    );
  }

  Future<void> desktopPurchaseFlow(
      Android provider, WidgetRef ref, BuildContext context) async {
    try {
      final userPlan =
          ref.read(plansNotifierProvider.notifier).getSelectedPlan();
      context.showLoadingDialog();

      ///Start stipe subscription flow
      final paymentProvider = ref.read(paymentNotifierProvider.notifier);
      final result = await paymentProvider.stripeSubscriptionLink(
        StipeSubscriptionType.one_time,
        userPlan.id,
      );
      result.fold(
        (error) {
          context.showSnackBarError(error.localizedErrorMessage);
          appLogger.error('Error subscribing to plan: $error');
          context.hideLoadingDialog();
        },
        (stripeUrl) async {
          // Handle success
          if (stripeUrl.isEmpty) {
            context.showSnackBarError('empty_url'.i18n);
            appLogger.error('Error subscribing to plan: empty url');
            context.hideLoadingDialog();
            return;
          }
          appLogger.info('Successfully started subscription flow');
          context.hideLoadingDialog();
          await Future.delayed(const Duration(milliseconds: 300));
          UrlUtils.openWebview<bool>(
            stripeUrl,
            title: 'stripe_payment'.i18n,
            onWebviewResult: (result) => onPurchaseResult(result, context),
          );
        },
      );
    } catch (e) {
      appLogger.error('Error subscribing to plan: $e');
      context.hideLoadingDialog();
      context.showSnackBarError('error_subscribing_plan'.i18n);
    }
  }

  void onPurchaseResult(bool purchased, BuildContext context) {
    if (purchased) {
      AppDialog.showLanternProDialog(
        context: context,
        onPressed: () {
          appRouter.push(
            CreatePassword(
              email: email,
              authFlow: authFlow,
            ),
          );
        },
      );
      return;
    }
    context.showSnackBarError('purchase_not_completed'.i18n);
  }
}

class PaymentCheckoutMethods extends HookConsumerWidget {
  final List<Android> providers;
  final Plan userPlan;
  final Function(Android provider) onSubscribe;

  const PaymentCheckoutMethods({
    super.key,
    required this.providers,
    required this.userPlan,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final planData = ref.watch(plansNotifierProvider.notifier).getPlanData();
    final iconData = planData.icons;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: providers.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final method = providers[index];
        return ExpansionTile(
          initiallyExpanded: index == 0,
          backgroundColor: AppColors.white,
          collapsedBackgroundColor: AppColors.white,
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.gray3,
              width: 1,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.gray3,
              width: 1,
            ),
          ),
          tilePadding: EdgeInsets.symmetric(horizontal: defaultSize),
          childrenPadding: EdgeInsets.symmetric(
              horizontal: defaultSize, vertical: defaultSize),
          title: Row(
            children: [
              Text(method.method, style: theme.titleMedium),
              SizedBox(width: defaultSize),
              LogsPath(
                logoPaths: iconData[method.providers.first.name]!,
              ),
            ],
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(userPlan.description, style: theme.bodyMedium),
                Text(
                  '${userPlan.formattedMonthlyPrice}/month',
                  style: theme.bodyMedium!.copyWith(
                    color: AppColors.gray6,
                  ),
                ),
              ],
            ),
            DividerSpace(padding: EdgeInsets.symmetric(vertical: 10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Total:',
                    style: theme.titleSmall!.copyWith(
                      color: AppColors.gray9,
                    )),
                Text(
                  userPlan.formattedYearlyPrice,
                  style: theme.titleSmall!.copyWith(
                    color: AppColors.blue10,
                  ),
                ),
              ],
            ),
            DividerSpace(padding: EdgeInsets.symmetric(vertical: 10)),
            SizedBox(height: 10),
            Text(
              "Billed every ${userPlan.getDurationText()}. Cancel anytime.",
              style: theme.bodySmall!.copyWith(
                color: AppColors.gray6,
              ),
            ),
            SizedBox(height: defaultSize),
            PrimaryButton(
              label: 'Subscribe',
              onPressed: () {
                onSubscribe.call(method);
              },
            )
          ],
        );
      },
    );
  }
}
