import 'package:flutter/material.dart';

import '../common/common.dart';

class BaseScreen extends StatelessWidget {
  final String title;
  final Widget body;
  final bool padded;
  final Widget? bottomNavigationBar;

  const BaseScreen({
    super.key,
    required this.title,
    required this.body,
    this.padded = true,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray1,
      appBar: CustomAppBar(title: title),
      body: Padding(
        padding: padded ? defaultPadding : EdgeInsets.zero,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
