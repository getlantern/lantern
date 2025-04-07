import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/screen_utils.dart';
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
          height: 24,
          child: LanternLogo(
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
                context.isSmallDevice ? size.height * 0.2 : size.height * 0.33,
            child: SingleChildScrollView(child: FeatureList()),
          ),
        ),
        SizedBox(height: defaultSize),
        Expanded(
          child: Container(
            color: AppColors.gray2,
            padding: defaultPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PlansListView(),
                SizedBox(height: 24),
                PrimaryButton(
                  label: 'Get Lantern Pro',
                  onPressed: () {},
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
                SizedBox(height: defaultSize),
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
      scrollControlDisabledMaxHeightRatio: 0.3,
      builder: (context, scrollController) {
        return ListView(
          shrinkWrap: true,
          controller: scrollController,
          children: [
            AppTile(
              icon: AppImagePaths.keypad,
              label: 'Enter an Activation Code',
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

class FeatureList extends StatelessWidget {
  const FeatureList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeatureTile(
            image: AppImagePaths.location,
            title: 'Select your server location'),
        _FeatureTile(
            image: AppImagePaths.blot,
            title: 'Faster speeds & unlimited bandwidth'),
        _FeatureTile(
            image: AppImagePaths.premium,
            title: 'Premium servers with less congestion'),
        _FeatureTile(
            image: AppImagePaths.eyeHide,
            title: 'Advanced anti-censorship technology'),
        _FeatureTile(
            image: AppImagePaths.roundCorrect,
            title: 'Exclusive access to new features'),
        _FeatureTile(
            image: AppImagePaths.connectDevice,
            title: 'Connect up to 5 devices'),
        _FeatureTile(
            image: AppImagePaths.adBlock, title: 'Built in ad blocking'),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String image;
  final String title;

  const _FeatureTile({super.key, required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppImage(
            path: image,
            color: AppColors.blue10,
            height: 24,
          ),
          SizedBox(width: defaultSize),
          Expanded(
            child: AutoSizeText(
              title,
              minFontSize: 10,
              maxLines: 1,
              maxFontSize: 16,
              overflow: TextOverflow.ellipsis,
              style: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}
