import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_image_paths.dart';

import '../../core/widgets/lantern_logo.dart';

@RoutePage(name: 'NewHome')
class NewHome extends StatefulWidget {
  const NewHome({super.key});

  @override
  State<NewHome> createState() => _NewHomeState();
}

class _NewHomeState extends State<NewHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const LanternLogo(),
          leading: IconButton(
              onPressed: () {
                app
              },
              icon: const AppAsset(path: AppImagePaths.menu))),
    );
    // drawer: const AppAsset(path: AppImagePaths.menu),
  }
}
