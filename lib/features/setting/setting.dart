import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_image_paths.dart';

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
        child: Column(
          children: <Widget>[
            PrimaryButton(
              label: 'Upgrade to Pro',
              icon: AppImagePaths.crown,
              expanded: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
