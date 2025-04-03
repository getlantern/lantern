import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'Plans')
class Plans extends StatefulWidget {
  const Plans({Key? key}) : super(key: key);

  @override
  State<Plans> createState() => _PlansState();
}

class _PlansState extends State<Plans> {
  late TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      backgroundColor: AppColors.gray0,
      appBar: CustomAppBar(
        title: "",
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
        FeatureList(),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          AppImage(
            path: image,
            color: AppColors.blue10,
            height: 24,
          ),
          SizedBox(width: defaultSize),
          Text(
            title,
            style: textTheme,
          ),
        ],
      ),
    );
  }
}
