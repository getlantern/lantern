import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/widgets/app_tile.dart';

import '../../core/widgets/divider_space.dart';

@RoutePage(name: 'Setting')
class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ListView(
          children: <Widget>[
            PrimaryButton(
              label: 'Upgrade to Pro',
              icon: AppImagePaths.crown,
              expanded: true,
              onPressed: () {},
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: AppTile(
                label: 'Sign In',
                icon: AppImagePaths.signIn,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    label: 'Split Tunneling',
                    icon: AppImagePaths.callSpilt,
                    onPressed: () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DividerSpace(),
                  ),
                  AppTile(
                    label: 'Server locations',
                    icon: AppImagePaths.location,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    label: 'Language',
                    icon: AppImagePaths.callSpilt,
                    onPressed: () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DividerSpace(),
                  ),
                  AppTile(
                    label: 'Server locations',
                    icon: AppImagePaths.location,
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    label: 'Language',
                    icon: AppImagePaths.translate,
                    onPressed: () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DividerSpace(),
                  ),
                  AppTile(
                    label: 'Appearance',
                    icon: AppImagePaths.theme,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    label: 'Support',
                    icon: AppImagePaths.support,
                    onPressed: () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DividerSpace(),
                  ),
                  AppTile(
                    label: 'Follow us',
                    icon: AppImagePaths.thumb,
                    onPressed: () {},

                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DividerSpace(),
                  ),
                  AppTile(
                    label: 'Get 30 days of Pro free',
                    icon: AppImagePaths.star,
                    onPressed: () {},
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DividerSpace(),
                  ),
                  AppTile(
                    label: 'Download Links',
                    icon: AppImagePaths.desktop,
                    onPressed: () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DividerSpace(),
                  ),
                  AppTile(
                    label: 'Check for updates',
                    icon: AppImagePaths.update,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
