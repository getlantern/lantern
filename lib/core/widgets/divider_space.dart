import 'package:flutter/material.dart';

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
        // border.default: Gray.200 light / Gray.800 dark
        // color: AppColors.gray2,
        color: Theme.of(context).dividerTheme.color,
        height: 1,
      ),
    );
  }
}
