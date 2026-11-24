import 'package:flutter/material.dart';

import '../common/common.dart';

class BaseScreen extends StatelessWidget {
  final String title;
  final Widget body;
  final bool padded;
  final AppBar? appBar;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool extendBody;
  final bool? resizeToAvoidBottomInset;

  const BaseScreen({
    super.key,
    required this.title,
    required this.body,
    this.padded = true,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
    this.extendBody = false,
    this.bottomSheet,
    this.resizeToAvoidBottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      // backgroundColor: backgroundColor ?? AppColors.gray1,
      appBar: appBar ??
          CustomAppBar(
            title: Text(title),
          ),
      body: Padding(
        // The TV shell's lists run off the bottom edge: no bottom padding
        // here, and a list that wants its last row inside the safe area
        // reads the panel's MediaQuery padding (a SafeArea does).
        padding: padded
            ? (PlatformUtils.tvShellEnabled
                ? defaultPadding.copyWith(bottom: 0)
                : defaultPadding)
            : EdgeInsets.zero,
        child: body,
      ),
      bottomSheet: bottomSheet,
      bottomNavigationBar: bottomNavigationBar,
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}
