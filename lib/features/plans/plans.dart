import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/formatter.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/auth/provider/payment_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/plans/feature_list.dart';
import 'package:lantern/features/plans/plans_list.dart';
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
      backgroundColor: AppColors.white,
      padded: false,
      appBar: CustomAppBar(
        title: SizedBox(
          height: 20.h,
          child: LanternLogo(
            color: AppColors.gray9,
            isPro: true,
          ),
        ),
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            appRouter.maybePop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: onMenuTap,
          ),
        ],
      ),
      title: "",
      body: _buildBody(),
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
            height:
                context.isSmallDevice ? size.height * 0.4 : size.height * 0.4,
            child: SingleChildScrollView(child: FeatureList()),
          ),
        ),
        SizedBox(height: defaultSize),
        DividerSpace(padding: EdgeInsets.zero),
        Expanded(
          child: Container(
            color: AppColors.gray1,
            padding: EdgeInsets.symmetric(
                horizontal: context.isSmallDevice ? 0 : defaultSize),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 10),
                Padding(
                  padding:
                      EdgeInsets.only(left: context.isSmallDevice ? 16 : 0),
                  child: plansState.when(
                    data: (data) {
                      return PlansListView(
                        data: data,
                        onPlanSelected: (plans) {},
                      );
                    },
                    loading: () {
                      return Center(
                        child: LoadingIndicator(),
                      );
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
                      horizontal: context.isSmallDevice ? defaultSize : 0),
                  child: PrimaryButton(
                    label: 'get_lantern_pro'.i18n,
                    isTaller: true,
                    onPressed: onGetLanternProTap,
                  ),
                ),
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
                appRouter
                    .popAndPush(AddEmail(authFlow: AuthFlow.activationCode));
              },
            ),
            DividerSpace(),
            AppTile(
              icon: AppImagePaths.restorePurchase,
              label: 'restore_purchase'.i18n,
              onPressed: () {
                appRouter.popAndPush(SignInEmail());
              },
            )
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
          Text('referral_code'.i18n,
              style: textTheme.headlineSmall!.copyWith(
                color: AppColors.gray9,
              )),
          SizedBox(height: 24),
          AppTextField(
            label: 'referral_code'.i18n,
            controller: referralCodeController,
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
            maxLength: 6,
            hintText: 'XXXXXX',
            prefixIcon: AppImagePaths.star,
          )
        ],
      ),
      action: [
        AppTextButton(
          label: 'cancel'.i18n,
          underLine: false,
          textColor: AppColors.gray6,
          onPressed: () {
            appRouter.pop();
          },
        ),
        AppTextButton(
          label: 'continue'.i18n,
          onPressed: () => onReferralCodeContinue(
              referralCodeController.text.toUpperCase().trim()),
        )
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
    final result =
        await ref.read(referralProvider.notifier).applyReferralCode(code);

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
            content: error.localizedErrorMessage);
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
        'Get Lantern Pro button tapped with plan: ${userSelectedPlan.id}');
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

  Future<void> startInAppPurchaseFlow(Plan plan) async {
    context.showLoadingDialog();
    final payments = ref.read(paymentProvider.notifier);
    final result = await payments.startInAppPurchaseFlow(
      planId: plan.id,
      onSuccess: (purchase) {
        /// Subscription successful
        context.hideLoadingDialog();
        acknowledgeInAppPurchase(
            purchase.verificationData.serverVerificationData, plan.id);
      },
      onError: (error) {
        if (!mounted) {
          return;
        }

        ///Error while subscribing
        context.showSnackBar(error);
        appLogger.error('Error subscribing to plan: $error');
        context.hideLoadingDialog();
      },
    );
    // Check if got any error while starting subscription flow
    result.fold(
      (error) {
        context.hideLoadingDialog();
        context.showSnackBar(error.localizedErrorMessage);
        appLogger.error('Error subscribing to plan: $error');
      },
      (success) {
        // Handle success
        appLogger.info('Successfully started subscription flow');
      },
    );
  }

  Future<void> acknowledgeInAppPurchase(
      String purchaseToken, String planId) async {
    appLogger.debug("Acknowledging purchase");
    context.showLoadingDialog();
    final result =
        await ref.read(paymentProvider.notifier).acknowledgeInAppPurchase(
              purchaseToken: purchaseToken,
              planId: planId,
            );
    result.fold(
      (error) {
        context.hideLoadingDialog();
        context.showSnackBar(error.localizedErrorMessage);
        appLogger.error('Error acknowledging purchase: $error');
      },
      (success) {
        // Handle success
        appLogger.info('Successfully acknowledged purchase');
        context.hideLoadingDialog();
        signUpFlow();
      },
    );
  }

  void signUpFlow() {
    final appSetting = ref.read(appSettingProvider);
    if (appSetting.userLoggedIn) {
      appLogger.info('User already logged in, checking account status');
      useProFlow();
      return;
    }
    appLogger.debug('Sending user to AddEmail screen for sign up');
    appRouter.push(AddEmail(authFlow: AuthFlow.signUp));
  }

  //This will be used for user has signed and there plan is expired
  Future<void> useProFlow() async {
    if (!mounted) {
      return;
    }
    context.showLoadingDialog();
    appLogger.debug("Checking user account status");
    final isPro = await checkUserAccountStatus(ref, context);
    context.hideLoadingDialog();
    if (isPro) {
      /// User should not reach here if they are pro, but just in case show them the dialog
      /// This just to avoid confusion
      /// BUT USER SHOULD NOT REACH HERE IF THEY ARE PRO
      appLogger.debug("User is Pro, showing Lantern Pro dialog");
      AppDialog.showLanternProDialog(
        context: context,
        onPressed: () {
          appRouter.popUntilRoot();
        },
      );
    } else {
      /// User is here because they are not pro but user has created an account
      /// There can be few reason for this
      /// 1. App crashed before completing the purchase flow
      /// 2. User cancelled the purchase flow while signing up

      /// In both case send user to confirm email screen
      /// Once done send user to subscription screen
      /// THIS IS JUST TO AVOID USER FROM BLOCKING FLOW
      context.showLoadingDialog();
      final appSetting = ref.read(appSettingProvider);
      final email = appSetting.email;
      final result =
          await ref.read(authProvider.notifier).startRecoveryByEmail(email);
      result.fold(
        (failure) {
          context.hideLoadingDialog();
          context.showSnackBar(failure.localizedErrorMessage);
        },
        (_) {
          context.hideLoadingDialog();
          appLogger.debug(
              'User has created account but is not Pro. Sending to Confirm Email screen to verification '
              'this is just avoid user from blocking flow.');

          appRouter.push(ConfirmEmail(email: email, authFlow: AuthFlow.signUp));
        },
      );
    }
  }
}
