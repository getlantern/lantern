import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/stripe_service.dart';
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
    final plansAsync = ref.watch(plansProvider);
    final paymentRedirectInFlight = useState(false);

    return BaseScreen(
      title: '',
      appBar: CustomAppBar(
        title: Text('choose_payment_method'.i18n),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => onMoreOptionsPressed(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: defaultSize),
          Expanded(
            child: plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text(e.toString())),
              data: (planData) {
                final providers = PlatformUtils.isAndroid
                    ? planData.providers.android
                    : planData.providers.desktop;

                return PaymentCheckoutMethods(
                  providers: providers,
                  userPlan: userPlan,
                  isSubmitting: paymentRedirectInFlight.value,
                  onSubscribe: (provider) => onSubscribe(
                    provider,
                    ref,
                    context,
                    paymentRedirectInFlight,
                  ),
                );
              },
            ),
          ),
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
          Text('referral_code'.i18n, style: textTheme.headlineSmall),
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
          textColor: context.textDisabled,
          underLine: false,
          onPressed: () {
            appRouter.pop();
          },
        ),
        AppTextButton(label: 'continue'.i18n, onPressed: () {}),
      ],
    );
  }

  Future<void> onSubscribe(
    Android provider,
    WidgetRef ref,
    BuildContext context,
    ValueNotifier<bool> paymentRedirectInFlight,
  ) async {
    final isDesktop = PlatformUtils.isDesktop;
    final isAndroid = PlatformUtils.isAndroid;
    final isAndroidSideload = isAndroid && !isStoreVersion();
    appLogger.info('User initiated purchase with provider: ${provider.method}');
    switch (provider.providers.name) {
      case 'stripe':
        if (isDesktop) {
          await desktopStripePurchaseFlow(
            provider,
            ref,
            context,
            paymentRedirectInFlight,
          );
          return;
        }

        if (isAndroidSideload) {
          await androidStripeSubscription(
            provider,
            ref,
            context,
            paymentRedirectInFlight,
          );
          return;
        }

        break;

      case 'shepherd':
        if (isDesktop || isAndroidSideload) {
          await paymentRedirectFlow(
            provider.providers.name,
            ref,
            context,
            paymentRedirectInFlight,
          );
          return;
        }
        break;
    }
  }

  Future<void> androidStripeSubscription(
    Android provider,
    WidgetRef ref,
    BuildContext context,
    ValueNotifier<bool> paymentRedirectInFlight,
  ) async {
    if (!beginPaymentRedirect(paymentRedirectInFlight)) return;
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
        finishPaymentRedirect(paymentRedirectInFlight);
      },
      (stripeData) async {
        // Handle success
        context.hideLoadingDialog();

        /// Start stripe SDK. The flag is cleared inside the SDK callbacks
        /// since startStripeSDK returns before the user finishes the flow.
        sl<StripeService>().startStripeSDK(
          context: context,
          options: StripeOptions.fromJson(stripeData),
          onSuccess: () {
            finishPaymentRedirect(paymentRedirectInFlight);
            onPurchaseResult(true, context, ref);
          },
          onError: (error) {
            finishPaymentRedirect(paymentRedirectInFlight);
            ///error while subscribing
            appLogger.error('Error subscribing to plan: $error');
            if (error is StripeException) {
              context.showSnackBar(
                error.error.localizedMessage ?? error.localizedDescription,
              );
              return;
            }
            context.showSnackBar(error.toString());
          },
        );
      },
    );
  }

  Future<void> desktopStripePurchaseFlow(
    Android provider,
    WidgetRef ref,
    BuildContext context,
    ValueNotifier<bool> paymentRedirectInFlight,
  ) async {
    if (!beginPaymentRedirect(paymentRedirectInFlight)) return;
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
      if (!context.mounted) return;
      await result.fold<Future<void>>(
        (error) async {
          context.showSnackBar(error.localizedErrorMessage);
          appLogger.error('Error subscribing to plan: $error');
          context.hideLoadingDialog();
        },
        (stripeUrl) async {
          final normalizedStripeUrl = UrlUtils.normalizeWebviewUrl(stripeUrl);
          if (normalizedStripeUrl.isEmpty) {
            context.showSnackBar('empty_url'.i18n);
            appLogger.error('Error subscribing to plan: empty redirect URL');
            context.hideLoadingDialog();
            return;
          }
          if (!UrlUtils.isSupportedWebviewUrl(normalizedStripeUrl)) {
            context.showSnackBar('it_looks_like_something_went_wrong'.i18n);
            appLogger.error(
              'Error subscribing to plan: invalid redirect URL: $stripeUrl',
            );
            context.hideLoadingDialog();
            return;
          }
          appLogger.info('Successfully started stripe subscription flow');
          context.hideLoadingDialog();
          // Let the loading dialog finish dismissing before opening the webview.
          await Future.delayed(const Duration(milliseconds: 300));
          if (!context.mounted) return;
          ref.read(paymentSessionProvider.notifier).markRedirectInitiated();
          try {
            final purchaseResult = await UrlUtils.openWebview<bool>(
              normalizedStripeUrl,
              title: 'stripe_payment'.i18n,
            );
            if (!context.mounted || purchaseResult == null) return;
            await onPurchaseResult(purchaseResult, context, ref);
          } catch (_) {
            ref.read(paymentSessionProvider.notifier).clearRedirect();
            rethrow;
          }
        },
      );
    } catch (e) {
      appLogger.error('Error subscribing to plan: $e');
      if (!context.mounted) return;
      context.hideLoadingDialog();
      context.showSnackBar(e.localizedDescription);
    } finally {
      finishPaymentRedirect(paymentRedirectInFlight);
    }
  }

  Future<void> paymentRedirectFlow(
    String provider,
    WidgetRef ref,
    BuildContext context,
    ValueNotifier<bool> paymentRedirectInFlight,
  ) async {
    if (!beginPaymentRedirect(paymentRedirectInFlight)) return;
    try {
      context.showLoadingDialog();
      final userPlan = ref.read(plansProvider.notifier).getSelectedPlan();
      final result = await ref
          .read(paymentProvider.notifier)
          .paymentRedirect(
            provider: provider,
            planId: userPlan.id,
            email: email,
          );
      if (!context.mounted) return;

      await result.fold<Future<void>>(
        (failure) async {
          context.hideLoadingDialog();
          appLogger.error(
            'Error redirecting to payment: ${failure.localizedErrorMessage}',
          );
          context.showSnackBar(failure.localizedErrorMessage);
        },
        (url) async {
          context.hideLoadingDialog();
          final normalizedUrl = UrlUtils.normalizeWebviewUrl(url);
          if (normalizedUrl.isEmpty) {
            context.showSnackBar('empty_url'.i18n);
            appLogger.error('Empty payment redirect URL');
            return;
          }
          if (!UrlUtils.isSupportedWebviewUrl(normalizedUrl)) {
            context.showSnackBar('it_looks_like_something_went_wrong'.i18n);
            appLogger.error('Invalid payment redirect URL: $url');
            return;
          }

          ref.read(paymentSessionProvider.notifier).markRedirectInitiated();
          try {
            final purchaseResult = await UrlUtils.openWebview<bool>(
              normalizedUrl,
            );
            if (!context.mounted || purchaseResult == null) return;
            await onPurchaseResult(purchaseResult, context, ref);
          } catch (e) {
            ref.read(paymentSessionProvider.notifier).clearRedirect();
            appLogger.error('Error opening payment redirect URL: $e');
            if (!context.mounted) return;
            context.showSnackBar('it_looks_like_something_went_wrong'.i18n);
          }
        },
      );
    } finally {
      finishPaymentRedirect(paymentRedirectInFlight);
    }
  }

  bool beginPaymentRedirect(ValueNotifier<bool> paymentRedirectInFlight) {
    if (paymentRedirectInFlight.value) {
      appLogger.info('Payment redirect already in progress');
      return false;
    }
    paymentRedirectInFlight.value = true;
    return true;
  }

  void finishPaymentRedirect(ValueNotifier<bool> paymentRedirectInFlight) {
    paymentRedirectInFlight.value = false;
  }

  Future<void> onPurchaseResult(
    bool purchased,
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!purchased) {
      context.showSnackBar('purchase_not_completed'.i18n);
      ref.read(paymentSessionProvider.notifier).clearRedirect();
      return;
    }
    context.showLoadingDialog();
    final isPro = await checkUserAccountStatus(ref, context);
    if (!context.mounted) return;
    context.hideLoadingDialog();
    if (isPro) {
      ref.read(paymentSessionProvider.notifier).clearRedirect();
      resolveRoute(context);
    } else {
      context.showSnackBar('purchase_not_completed'.i18n);
    }
  }

  void resolveRoute(BuildContext context) {
    switch (authFlow) {
      case AuthFlow.signUp:
        appRouter.push(
          CreatePassword(email: email, authFlow: authFlow, code: code!),
        );
        break;
      case AuthFlow.oauth:
        AppDialog.showLanternProDialog(
          context: context,
          onPressed: () {
            appRouter.popUntilRoot();
          },
        );
        break;
      case AuthFlow.lanternProLicense:
        throw UnimplementedError('Activation code flow should not reach here');

      case AuthFlow.resetPassword:
        // TODO: Handle this case.
        throw UnimplementedError('reset password flow should not reach here');
      case AuthFlow.changeEmail:
        // TODO: Handle this case.
        throw UnimplementedError('change email flow should not reach here');
      case AuthFlow.renewSubscription:
        AppDialog.showLanternProDialog(
          context: context,
          onPressed: () {
            appRouter.popUntilRoot();
          },
        );
    }
  }
}

class PaymentCheckoutMethods extends HookConsumerWidget {
  final List<Android> providers;
  final Plan userPlan;
  final bool isSubmitting;
  final Function(Android provider) onSubscribe;

  const PaymentCheckoutMethods({
    super.key,
    required this.providers,
    required this.userPlan,
    required this.isSubmitting,
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
            backgroundColor: context.bgElevated,
            collapsedBackgroundColor: context.bgElevated,
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.borderInput, width: 1),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.borderInput, width: 1),
            ),
            tilePadding: EdgeInsets.symmetric(
              horizontal: defaultSize,
              vertical: 2,
            ),
            childrenPadding: EdgeInsets.symmetric(
              horizontal: defaultSize,
              vertical: defaultSize,
            ),
            title: Row(
              children: [
                Text(
                  method.method.replaceAll('-', " ").toTitleCase(),
                  style: theme.titleMedium,
                ),
                SizedBox(width: defaultSize),
                LogsPath(logoPaths: method.providers.icons),
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
                      color: context.textDisabled,
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
                      getReferralMessage(
                        userPlan.id,
                      ).replaceAll('free', '').toTitleCase(),
                      style: theme.bodyMedium,
                    ),
                    Text(
                      'free'.i18n,
                      style: theme.bodyMedium!.copyWith(
                        color: context.textDisabled,
                      ),
                    ),
                  ],
                ),
                DividerSpace(padding: EdgeInsets.symmetric(vertical: 10)),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Total:',
                    style: theme.titleSmall!.copyWith(
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    userPlan.formattedYearlyPrice,
                    style: theme.titleSmall!.copyWith(
                      color: context.actionPrimaryBg,
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
                style: theme.bodySmall!.copyWith(color: context.textDisabled),
              ),
              SizedBox(height: defaultSize),
              PrimaryButton(
                label: method.providers.supportSubscription
                    ? 'subscribe'.i18n
                    : 'checkout'.i18n,
                enabled: !isSubmitting,
                onPressed: () {
                  onSubscribe.call(method);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
