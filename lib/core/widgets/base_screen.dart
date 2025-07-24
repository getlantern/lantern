import 'package:flutter/material.dart';

import '../common/common.dart';

class BaseScreen extends StatelessWidget {
  final String title;
  final Widget body;
  final bool padded;
  final AppBar? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const BaseScreen({
    super.key,
    required this.title,
    required this.body,
    this.padded = true,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.gray1,
      appBar: appBar ??
          CustomAppBar(
            title: Text(title),
          ),
      body: Padding(
        padding: padded ? defaultPadding : EdgeInsets.zero,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
