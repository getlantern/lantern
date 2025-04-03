import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/screen_utils.dart';

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
            onPressed: () {},
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
        Center(
          child: SizedBox(
            height: 24,
            child: LanternLogo(
              isPro: true,
            ),
          ),
        ),
        SizedBox(height: defaultSize),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: defaultSize),
          child: SizedBox(
            height:
                context.isSmallDevice ? size.height * 0.2 : size.height * 0.325,
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
}

class PlansListView extends StatelessWidget {
  const PlansListView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final finalSize = (width * 0.5) - (defaultSize * 3);
    print('width: $width');
    print('finalSize: $finalSize');

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        badges.Badge(
          badgeAnimation: badges.BadgeAnimation.scale(
            toAnimate: false,
          ),
          position: badges.BadgePosition.custom(
            top: -15,
            start: (finalSize - 10),
          ),
          // Adjust values as needed
          badgeStyle: badges.BadgeStyle(
            shape: badges.BadgeShape.square,
            borderSide: BorderSide(
              color: AppColors.yellow4,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
            badgeColor: AppColors.yellow3,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          badgeContent: Text(
            'Best Value!',
            style: textTheme.labelMedium,
          ),
          child: AnimatedContainer(
            margin: EdgeInsets.only(bottom: defaultSize),
            padding:
                EdgeInsets.symmetric(horizontal: defaultSize, vertical: 10),
            duration: Duration(milliseconds: 300),
            decoration: selectedDecoration,
            child: Row(
              children: <Widget>[
                Text(
                  'Two Year Plan',
                  style: textTheme.titleMedium,
                ),
                Spacer(),
                Column(
                  children: <Widget>[
                    Text(
                      '\$87.00',
                      style: textTheme.titleMedium!.copyWith(
                        color: AppColors.blue7,
                      ),
                    ),
                    Text(
                      '\$3.64/month',
                      style: textTheme.labelMedium!.copyWith(
                        color: AppColors.gray7,
                      ),
                    ),
                  ],
                ),
                Radio(
                  value: true,
                  groupValue: false,
                  fillColor: WidgetStatePropertyAll(AppColors.gray9),
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          margin: EdgeInsets.only(bottom: defaultSize),
          padding: EdgeInsets.symmetric(horizontal: defaultSize, vertical: 10),
          duration: Duration(milliseconds: 300),
          decoration: unselectedDecoration,
          child: Row(
            children: <Widget>[
              Text(
                'Two Year Plan',
                style: textTheme.titleMedium,
              ),
              Spacer(),
              Column(
                children: <Widget>[
                  Text(
                    '\$87.00',
                    style: textTheme.titleMedium!.copyWith(
                      color: AppColors.blue7,
                    ),
                  ),
                  Text(
                    '\$3.64/month',
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                    ),
                  ),
                ],
              ),
              Radio(
                value: true,
                groupValue: false,
                fillColor: WidgetStatePropertyAll(AppColors.gray9),
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        AnimatedContainer(
          padding: EdgeInsets.symmetric(horizontal: defaultSize, vertical: 10),
          duration: Duration(milliseconds: 300),
          decoration: unselectedDecoration,
          child: Row(
            children: <Widget>[
              Text(
                'Two Year Plan',
                style: textTheme.titleMedium,
              ),
              Spacer(),
              Column(
                children: <Widget>[
                  Text(
                    '\$87.00',
                    style: textTheme.titleMedium!.copyWith(
                      color: AppColors.blue7,
                    ),
                  ),
                  Text(
                    '\$3.64/month',
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                    ),
                  ),
                ],
              ),
              Radio(
                value: true,
                groupValue: false,
                fillColor: WidgetStatePropertyAll(AppColors.gray9),
                onChanged: (value) {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration get selectedDecoration {
    return BoxDecoration(
      color: AppColors.blue1,
      border: Border.all(color: AppColors.blue7, width: 3),
      borderRadius: BorderRadius.circular(16),
    );
  }

  BoxDecoration get unselectedDecoration {
    return BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.gray3, width: 1.5),
      borderRadius: BorderRadius.circular(16),
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
