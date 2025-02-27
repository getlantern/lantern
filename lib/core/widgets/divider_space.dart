import 'package:flutter/material.dart';

import '../common/app_colors.dart';

class DividerSpace extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const DividerSpace({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Divider(
        color: AppColors.gray2,
        height: 1,
      ),
    );
  }
}
