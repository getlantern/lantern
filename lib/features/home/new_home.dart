import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/router/router.gr.dart';

import '../../core/common/common.dart';

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
                appRouter.push(const Setting());
              },
              icon: const AppAsset(path: AppImagePaths.menu))),
    );
  }
}
