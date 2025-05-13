import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/core/utils/store_utils.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/auth/provider/payment_notifier.dart';
import 'package:lantern/features/plans/feature_list.dart';
import 'package:lantern/features/plans/plans_list.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';

import '../../core/models/plan_data.dart';

@RoutePage(name: 'Plans')
class Plans extends HookConsumerWidget {
  const Plans({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    void nonStoreFlow() {
      if (PlatformUtils.isIOS) {
        throw Exception('Not supported on IOS');
      }
      appRouter
          .push(AddEmail(authFlow: AuthFlow.signUp, appFlow: AppFlow.nonStore));
    }

    void storeFlow() {
      appRouter
          .push(AddEmail(authFlow: AuthFlow.signUp, appFlow: AppFlow.store));
    }

    Future<void> startInAppPurchaseFlow(Plan plan) async {
      context.showLoadingDialog();
      final paymentProvider = ref.read(paymentNotifierProvider.notifier);
      final result = await paymentProvider.startInAppPurchaseFlow(
        planId: plan.id,
        onSuccess: (purchase) {
          /// Subscription successful
          //todo call api to acknowledge the purchase
          context.hideLoadingDialog();
          storeFlow();
        },
        onError: (error) {
          ///Error while subscribing
          context.showSnackBarError(error);
          appLogger.error('Error subscribing to plan: $error');
          context.hideLoadingDialog();
        },
      );
      // Check if got any error while starting subscription flow
      result.fold(
        (error) {
          context.hideLoadingDialog();
          context.showSnackBarError(error.localizedErrorMessage);
          appLogger.error('Error subscribing to plan: $error');
        },
        (success) {
          // Handle success
          appLogger.info('Successfully started subscription flow');
        },
      );
    }

    void onGetLanternProTap() {
      final userSelectedPlan =
          ref.read(plansNotifierProvider.notifier).getSelectedPlan();
      switch (Platform.operatingSystem) {
        case 'android':
          if (sl<StoreUtils>().isPlayStoreVersion) {
            /// user is using play store version
            startInAppPurchaseFlow(userSelectedPlan);
            return;
          }
          nonStoreFlow();
          break;
        case 'ios':
          startInAppPurchaseFlow(userSelectedPlan);
          break;
        default:
          nonStoreFlow();
      }
    }

    Widget _buildBody() {
      final plansState = ref.watch(plansNotifierProvider);
      final size = MediaQuery.of(context).size;
      return Column(
        children: [
          SizedBox(height: defaultSize),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: defaultSize),
            child: SizedBox(
              height: context.isSmallDevice
                  ? size.height * 0.4
                  : size.height * 0.33,
              child: SingleChildScrollView(child: FeatureList()),
            ),
          ),
          SizedBox(height: defaultSize),
          Expanded(
            child: Container(
              color: AppColors.gray2,
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
                                ref
                                    .read(plansNotifierProvider.notifier)
                                    .fetchPlans();
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
                      label: 'Get Lantern Pro',
                      onPressed: onGetLanternProTap,
                    ),
                  ),
                  SizedBox(height: defaultSize),
                  Center(
                    child: Text(
                      'Plan automatically renews until canceled',
                      style: textTheme.labelMedium!.copyWith(
                        color: AppColors.gray7,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      );
    }

    void onMenuTap() {
      showAppBottomSheet(
        context: context,
        title: 'payment_options'.i18n,
        scrollControlDisabledMaxHeightRatio: context.isSmallDevice ? 0.4 : 0.3,
        builder: (context, scrollController) {
          return ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            controller: scrollController,
            children: [
              AppTile(
                icon: AppImagePaths.keypad,
                label: 'Enter an Activation Code',
                onPressed: () {
                  appRouter
                      .popAndPush(AddEmail(authFlow: AuthFlow.activationCode));
                },
              ),
              DividerSpace(),
              AppTile(
                icon: AppImagePaths.restorePurchase,
                label: 'Restore purchase',
              )
            ],
          );
        },
      );
    }

    return BaseScreen(
      backgroundColor: AppColors.white,
      padded: false,
      appBar: CustomAppBar(
        title: "",
        titleWidget: SizedBox(
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
            context.router.maybePop();
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
}
