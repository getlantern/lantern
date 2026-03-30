import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/formatter.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/plans/feature_list.dart';
import 'package:lantern/features/plans/plans_list.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';

import '../../core/models/plan_data.dart';

@RoutePage(name: 'Plans')
class Plans extends StatefulHookConsumerWidget {
  const Plans({super.key});

  @override
  ConsumerState<Plans> createState() => _PlansState();
}

class _PlansState extends ConsumerState<Plans> {
  late TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      backgroundColor: context.bgElevated,
      padded: false,
      appBar: CustomAppBar(
        title: SizedBox(
          height: 20.h,
          child: LanternLogo(color: context.textPrimary, isPro: true),
        ),
        backgroundColor: context.bgElevated,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            appRouter.maybePop();
          },
        ),
        actions: [
          IconButton(icon: Icon(Icons.more_vert), onPressed: onMenuTap),
        ],
      ),
      title: "",
      body: SafeArea(bottom: !PlatformUtils.isIOS, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final plansState = ref.watch(plansProvider);
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: defaultSize),
          child: SizedBox(
            height: context.isSmallDevice
                ? size.height * 0.4
                : size.height * 0.39,
            child: SingleChildScrollView(child: FeatureList()),
          ),
        ),
        SizedBox(height: defaultSize),
        DividerSpace(padding: EdgeInsets.zero),
        Expanded(
          child: Container(
            color: context.bgSurface,
            padding: EdgeInsets.symmetric(
              horizontal: context.isSmallDevice ? 0 : defaultSize,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(
                    left: context.isSmallDevice ? 16 : 0,
                  ),
                  child: plansState.when(
                    data: (data) {
                      return PlansListView(data: data);
                    },
                    loading: () {
                      return Center(child: LoadingIndicator());
                    },
                    error: (error, stackTrace) {
                      return Column(
                        children: [
                          Text(
                            'plans_fetch_error'.i18n,
                            style: textTheme.labelLarge,
                          ),
                          AppTextButton(
                            label: 'Try again',
                            onPressed: () {
                              ref.read(plansProvider.notifier).fetchPlans();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isSmallDevice ? defaultSize : 0,
                  ),
                  child: PrimaryButton(
                    label: 'get_lantern_pro'.i18n,
                    isTaller: true,
                    onPressed: onGetLanternProTap,
                  ),
                ),
                if (PlatformUtils.isIOS) ...{
                  SizedBox(height: defaultSize),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      'subscription_renewal_info'.i18n,
                      style: textTheme.labelMedium!.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        AppTextButton(
                          label: 'privacy_policy'.i18n,
                          fontSize: 12,
                          textColor: context.textTertiary,
                          onPressed: () {
                            UrlUtils.openWithSystemBrowser(
                              AppUrls.privacyPolicy,
                            );
                          },
                        ),
                        VerticalDivider(indent: 10, endIndent: 10),
                        AppTextButton(
                          label: 'terms_of_service'.i18n,
                          fontSize: 12,
                          textColor: context.textTertiary,
                          onPressed: () {
                            UrlUtils.openWithSystemBrowser(
                              AppUrls.termsOfService,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                },
                SizedBox(height: size24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void onMenuTap() {
    final isReferralApplied = ref.read(referralProvider);
    showAppBottomSheet(
      context: context,
      title: 'payment_options'.i18n,
      scrollControlDisabledMaxHeightRatio: context.isSmallDevice ? 0.5 : 0.4,
      builder: (context, scrollController) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          controller: scrollController,
          children: [
            if (!isStoreVersion() && !isReferralApplied) ...{
              AppTile(
                icon: AppImagePaths.star,
                label: 'referral_code'.i18n,
                onPressed: () {
                  context.pop();
                  showReferralCodeDialog();
                },
              ),
              DividerSpace(),
            },
            AppTile(
              icon: AppImagePaths.keypad,
              label: 'lantern_pro_license'.i18n,
              onPressed: () {
                appRouter.popAndPush(
                  AddEmail(authFlow: AuthFlow.lanternProLicense),
                );
              },
            ),
            DividerSpace(),
            AppTile(
              icon: AppImagePaths.restorePurchase,
              label: 'restore_purchase'.i18n,
              onPressed: () {
                appRouter.popAndPush(SignInEmail());
              },
            ),
          ],
        );
      },
    );
  }

  void showReferralCodeDialog() {
    final referralCodeController = TextEditingController();
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          AppImage(path: AppImagePaths.star, height: 48),
          SizedBox(height: defaultSize),
          Text(
            'referral_code'.i18n,
            style: textTheme.headlineSmall!.copyWith(
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: 24),
          AppTextField(
            label: 'referral_code'.i18n,
            controller: referralCodeController,
            inputFormatters: [UpperCaseTextFormatter()],
            hintText: 'XXXXXX',
            prefixIcon: AppImagePaths.star,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'cancel'.i18n,
          underLine: false,
          textColor: context.textDisabled,
          onPressed: () {
            appRouter.pop();
          },
        ),
        AppTextButton(
          label: 'continue'.i18n,
          onPressed: () => onReferralCodeContinue(
            referralCodeController.text.toUpperCase().trim(),
          ),
        ),
      ],
    );
  }

  Future<void> onReferralCodeContinue(String code) async {
    if (code.isEmpty) {
      context.showSnackBar('please_enter_referral_code'.i18n);
      return;
    }
    appRouter.pop();
    context.showLoadingDialog();
    final result = await ref
        .read(referralProvider.notifier)
        .applyReferralCode(code);

    result.fold(
      (error) {
        if (!mounted) {
          return;
        }
        appLogger.error('Error applying referral code: $error');
        context.hideLoadingDialog();
        AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: error.localizedErrorMessage,
        );
      },
      (success) {
        if (!mounted) {
          return;
        }
        context.hideLoadingDialog();
        context.showSnackBar('referral_code_applied'.i18n);
        appLogger.info('Successfully applied referral code');
      },
    );
  }

  void onGetLanternProTap() {
    final userSelectedPlan = ref.read(plansProvider.notifier).getSelectedPlan();
    appLogger.info(
      'Get Lantern Pro button tapped with plan: ${userSelectedPlan.id}',
    );

    final appSetting = ref.read(appSettingProvider);
    final isPro = ref.read(isUserProProvider);

    /// Pro user coming to renew — send directly to payment screen by platform
    if (appSetting.userLoggedIn && isPro) {
      appLogger.info('Pro user renewal flow, routing by platform');
      _renewalFlowByPlatform(userSelectedPlan);
      return;
    }

    switch (Platform.operatingSystem) {
      case 'android':
        if (isStoreVersion()) {
          /// user is using play store version
          appLogger.info('Starting in app purchase flow');
          startInAppPurchaseFlow(userSelectedPlan);
          return;
        }
        appLogger.info('Starting sign up flow for android');
        signUpFlow();
        break;
      case 'ios':
        appLogger.info('Starting in app purchase flow IOS');
        startInAppPurchaseFlow(userSelectedPlan);
        break;
      default:
        signUpFlow();
    }
  }

  void _renewalFlowByPlatform(Plan plan) {
    switch (Platform.operatingSystem) {
      case 'ios':
        appLogger.info('Pro renewal: starting in-app purchase flow for iOS');
        startInAppPurchaseFlow(plan);
        break;
      case 'android':
        if (isStoreVersion()) {
          appLogger.info(
            'Pro renewal: starting in-app purchase flow for Android store',
          );
          startInAppPurchaseFlow(plan);
          return;
        }
        appLogger.info('Pro renewal: routing to payment method screen');
        _pushRenewalPaymentScreen();
        break;
      default:
        appLogger.info('Pro renewal: routing to payment method screen');
        _pushRenewalPaymentScreen();
    }
  }

  void _pushRenewalPaymentScreen() {
    final user = ref.read(homeProvider).value;
    final email = user!.legacyUserData.email;
    appRouter.push(
      ChoosePaymentMethod(email: email, authFlow: AuthFlow.renewSubscription),
    );
  }

  Future<void> startInAppPurchaseFlow(Plan plan) async {
    context.showLoadingDialog();
    final payments = ref.read(paymentProvider.notifier);
    final result = await payments.startInAppPurchaseFlow(
      planId: plan.id,
      onSuccess: (purchase) => processPurchase(purchase, plan),
      onError: (error) {
        if (!mounted) return;
        context.showSnackBar(error);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
    );
    if (!mounted) return;
    result.fold((error) {
      context.hideLoadingDialog();
      context.showSnackBar(error.localizedErrorMessage);
      appLogger.error('Error subscribing to plan: $error');
    }, (_) {});
  }

  Future<void> processPurchase(PurchaseDetails purchase, Plan plan) async {
    context.hideLoadingDialog();
    appLogger.info('Subscription successful for plan: ${plan.id}');

    /// Refresh user data from core to update UI immediately after purchase acknowledgment.
    await ref.read(homeProvider.notifier).refreshUser();

    /// IOS Send old purchases to stream
    sl<AppPurchase>().clearCallbacks();

    final appSetting = ref.read(appSettingProvider);
    if (appSetting.userLoggedIn) {
      /// If user logged in and purchase is successful then check user account status
      /// to reflect new purchase and send user to pro flow
      userRenewalFlow();
      return;
    }
    signUpFlow();
  }

  void signUpFlow() {
    final appSetting = ref.read(appSettingProvider);
    if (appSetting.userLoggedIn) {
      final user = ref.read(homeProvider).value;
      final email = user!.legacyUserData.email;

      /// User is logged in but not pro — account created but purchase not completed or plan expired
      appRouter.push(
        ChoosePaymentMethod(email: email, authFlow: AuthFlow.renewSubscription),
      );
      return;
    }
    appLogger.debug('Sending user to AddEmail screen for sign up');
    appRouter.push(AddEmail(authFlow: AuthFlow.signUp));
  }

  Future<void> userRenewalFlow() async {
    appLogger.info('Purchase successful, verifying account status with server');
    context.showLoadingDialog();
    appLogger.debug("Checking user account status");
    final isPro = await checkUserAccountStatus(ref, context);
    context.hideLoadingDialog();
    if (isPro) {
      appLogger.debug("User is Pro, showing Lantern Pro dialog");
      AppDialog.showLanternProDialog(
        context: context,
        onPressed: () {
          appRouter.popUntilRoot();
        },
      );
      return;
    } else {
      appLogger.debug(
        "User has made purchase is not reflected in account status, showing Lantern Pro dialog just to avoid blocking flow",
      );
      AppDialog.dialog(
        context: context,
        title: "payment".i18n,
        content: 'it_looks_like_something_went_wrong'.i18n,
        onPressed: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appRouter.popUntilRoot();
          });
        },
      );
    }
  }
}
