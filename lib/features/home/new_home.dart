import 'package:flutter/material.dart';
import 'package:lantern/core/router/router.dart';

import '../../core/common/common.dart';

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
              onPressed: () => SettingRoute().go(context),
              icon: const AppAsset(path: AppImagePaths.menu))),
    );
  }
}
