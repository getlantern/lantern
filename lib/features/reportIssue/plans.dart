import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'Plans')
class Plans extends StatelessWidget {
  const Plans({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
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
        Center(child: FeatureList()),
      ],
    );
  }
}

class FeatureList extends StatelessWidget {
  const FeatureList({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.bodyLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          
            label: 'Select your server location',
            tileTextStyle: textTheme,
            icon: AppImagePaths.location),
        AppTile(
            label: 'Faster speeds & unlimited bandwidth',
            tileTextStyle: textTheme,
            icon: AppImage(path: AppImagePaths.blot,color: AppColors.blue1,))
      ],
    );
  }
}
