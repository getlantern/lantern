import 'package:flutter/material.dart';

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
              onPressed: () => Navigator.pushNamed(context, '/setting'),
              icon: const AppAsset(path: AppImagePaths.menu))),
    );
  }
}
