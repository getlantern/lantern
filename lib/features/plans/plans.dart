import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/features/plans/feature_list.dart';
import 'package:lantern/features/plans/plans_list.dart';

@RoutePage(name: 'Plans')
class Plans extends StatefulWidget {
  const Plans({super.key});

  @override
  State<Plans> createState() => _PlansState();
}

class _PlansState extends State<Plans> {
  late TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
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
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        SizedBox(height: defaultSize),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: defaultSize),
          child: SizedBox(
            height:
                context.isSmallDevice ? size.height * 0.4 : size.height * 0.33,
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
                SizedBox(height: defaultSize),
                Padding(
                  padding:
                      EdgeInsets.only(left: context.isSmallDevice ? 16 : 0),
                  child: PlansListView(),
                ),
                SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.isSmallDevice ? defaultSize : 0),
                  child: PrimaryButton(
                    label: 'Get Lantern Pro',
                    onPressed: () {},
                  ),
                ),
                SizedBox(height: 24),
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
}
