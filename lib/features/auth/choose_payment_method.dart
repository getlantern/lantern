import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/stripe_service.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/logs_path.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';

@RoutePage(name: 'ChoosePaymentMethod')
class ChoosePaymentMethod extends HookConsumerWidget {
  final String email;
  final String? code;
  final AuthFlow authFlow;

  const ChoosePaymentMethod({
    super.key,
    required this.email,
    this.code,
    required this.authFlow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPlan = ref.watch(plansProvider.notifier).getSelectedPlan();
    final planData = ref.watch(plansProvider.notifier).getPlanData();
    return BaseScreen(
      title: '',
      appBar: CustomAppBar(
        title: Text('choose_payment_method'.i18n),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () => onMoreOptionsPressed(context),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          InfoRow(
            minTileHeight: 40,
            imagePath: AppImagePaths.security,
            text: 'payment_information_encrypted'.i18n,
          ),
          SizedBox(height: defaultSize),
          Expanded(
            child: PaymentCheckoutMethods(
              providers: PlatformUtils.isAndroid
                  ? planData.providers.android
                  : planData.providers.desktop,
              userPlan: userPlan,
              onSubscribe: (provider) => onSubscribe(provider, ref, context),
            ),
          )
        ],
      ),
    );
  }

  void onMoreOptionsPressed(BuildContext context) {
    showAppBottomSheet(
      context: context,
      title: 'payment_options'.i18n,
      scrollControlDisabledMaxHeightRatio: .25,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppTile(
              label: 'add_referral_code'.i18n,
              icon: AppImagePaths.star,
              onPressed: () {
                appRouter.pop();
                showRferralCodeDialog(context);
              },
            ),
            DividerSpace(),
          ],
        );
      },
    );
  }

  void showRferralCodeDialog(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    AppDialog.customDialog(
        context: context,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: size24),
            AppImage(path: AppImagePaths.star, height: 40),
            SizedBox(height: defaultSize),
            Text(
              'referral_code'.i18n,
              style: textTheme.headlineSmall,
            ),
            SizedBox(height: defaultSize),
            AppTextField(
              label: 'referral_code'.i18n,
              hintText: 'XXXXXX',
              prefixIcon: AppImagePaths.star,
            ),
          ],
        ),
        action: [
          AppTextButton(
            label: 'cancel'.i18n,
            textColor: AppColors.gray8,
            underLine: false,
            onPressed: () {
              appRouter.pop();
            },
          ),
          AppTextButton(
            label: 'continue'.i18n,
            onPressed: () {},
          ),
        ]);
  }

  Future<void> onSubscribe(
      Android provider, WidgetRef ref, BuildContext context) async {
    final isDesktop = PlatformUtils.isDesktop;
    final isAndroid = PlatformUtils.isAndroid;
    final isAndroidSideload = isAndroid && !isStoreVersion();

    switch (provider.providers.name) {
      case 'stripe':
        if (isDesktop) {
          await desktopPurchaseFlow(provider, ref, context);
          return;
        }

        if (isAndroidSideload) {
          await androidStripeSubscription(provider, ref, context);
          return;
        }

        break;

      case 'shepherd':
        if (isDesktop || isAndroidSideload) {
          await paymentRedirectFlow(provider.providers.name, ref, context);
          return;
        }
        break;
    }
  }

  Future<void> androidStripeSubscription(
      Android provider, WidgetRef ref, BuildContext context) async {
    final userPlan = ref.read(plansProvider.notifier).getSelectedPlan();
    final payments = ref.read(paymentProvider.notifier);
    context.showLoadingDialog();

    ///get stripe details
    final result = await payments.stripeSubscription(userPlan.id, email);
    result.fold(
      (error) {
        context.showSnackBar(error.localizedErrorMessage);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
      (stripeData) async {
        // Handle success
        context.hideLoadingDialog();

        /// Start stripe SDK
        sl<StripeService>().startStripeSDK(
          options: StripeOptions.fromJson(stripeData),
          onSuccess: () {
            onPurchaseResult(true, context, ref);
          },
          onError: (error) {
            ///error while subscribing
            context.showSnackBar(error.toString());
          },
        );
      },
    );
  }

  Future<void> desktopPurchaseFlow(
      Android provider, WidgetRef ref, BuildContext context) async {
    try {
      final userPlan = ref.read(plansProvider.notifier).getSelectedPlan();
      context.showLoadingDialog();

      ///Start stipe subscription flow
      final payments = ref.read(paymentProvider.notifier);
      final result = await payments.stripeSubscriptionLink(
        BillingType.subscription,
        userPlan.id,
        email,
      );
      result.fold(
        (error) {
          context.showSnackBar(error.localizedErrorMessage);
          appLogger.error('Error subscribing to plan: $error');
          context.hideLoadingDialog();
        },
        (stripeUrl) async {
          // Handle success
          if (stripeUrl.isEmpty) {
            context.showSnackBar('empty_url'.i18n);
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
            onWebviewResult: (result) => onPurchaseResult(result, context, ref),
          );
        },
      );
    } catch (e) {
      appLogger.error('Error subscribing to plan: $e');
      context.hideLoadingDialog();
      context.showSnackBar(e.localizedDescription);
    }
  }

  Future<void> paymentRedirectFlow(
      String provider, WidgetRef ref, BuildContext context) async {
    context.showLoadingDialog();
    final userPlan = ref.watch(plansProvider.notifier).getSelectedPlan();
    final result = await ref.read(paymentProvider.notifier).paymentRedirect(
          provider: provider,
          planId: userPlan.id,
          email: email,
        );

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        appLogger.error(
            'Error redirecting to payment: ${failure.localizedErrorMessage}');
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (url) {
        context.hideLoadingDialog();
        UrlUtils.openWebview(url);
      },
    );
  }

  Future<void> onPurchaseResult(
      bool purchased, BuildContext context, WidgetRef ref) async {
    if (!purchased) {
      context.showSnackBar('purchase_not_completed'.i18n);
      return;
    }
    context.showLoadingDialog();
    final isPro = await checkUserAccountStatus(ref, context);
    context.hideLoadingDialog();
    if (isPro) {
      resolveRoute(context);
    } else {
      context.showSnackBar('purchase_not_completed'.i18n);
    }
  }

  void resolveRoute(BuildContext context) {
    switch (authFlow) {
      case AuthFlow.signUp:
        appRouter.push(
            CreatePassword(email: email, authFlow: authFlow, code: code!));
        break;
      case AuthFlow.oauth:
        AppDialog.showLanternProDialog(
          context: context,
          onPressed: () {
            appRouter.popUntilRoot();
          },
        );
        break;
      case AuthFlow.activationCode:
        throw UnimplementedError('Activation code flow should not reach here');
      case AuthFlow.resetPassword:
        // TODO: Handle this case.
        throw UnimplementedError('reset password flow should not reach here');
      case AuthFlow.changeEmail:
        // TODO: Handle this case.
        throw UnimplementedError('change email flow should not reach here');
    }
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
    final referralEnable = ref.watch(referralProvider);
    final theme = Theme.of(context).textTheme;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: providers.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final method = providers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
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
            tilePadding:
                EdgeInsets.symmetric(horizontal: defaultSize, vertical: 2),
            childrenPadding: EdgeInsets.symmetric(
                horizontal: defaultSize, vertical: defaultSize),
            title: Row(
              children: [
                Text(method.method.replaceAll('-', " ").toTitleCase(),
                    style: theme.titleMedium),
                SizedBox(width: defaultSize),
                LogsPath(
                  logoPaths: method.providers.icons,
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
              if (referralEnable) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        getReferralMessage(userPlan.id)
                            .replaceAll('free', '')
                            .toTitleCase(),
                        style: theme.bodyMedium),
                    Text(
                      'free'.i18n,
                      style: theme.bodyMedium!.copyWith(
                        color: AppColors.gray6,
                      ),
                    ),
                  ],
                ),
                DividerSpace(padding: EdgeInsets.symmetric(vertical: 10)),
              ],
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
                method.providers.supportSubscription
                    ? "Billed every ${userPlan.getDurationText()}. Cancel anytime."
                    : 'billed_once'.i18n.capitalize,
                style: theme.bodySmall!.copyWith(
                  color: AppColors.gray6,
                ),
              ),
              SizedBox(height: defaultSize),
              PrimaryButton(
                label: method.providers.supportSubscription
                    ? 'subscribe'.i18n
                    : 'checkout'.i18n,
                onPressed: () {
                  onSubscribe.call(method);
                },
              )
            ],
          ),
        );
      },
    );
  }
}
