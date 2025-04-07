import 'package:flutter/material.dart';

class CustomAppBar extends AppBar {
  final Widget? titleWidget;

  CustomAppBar({
    super.key,
    required String title,
    super.actions,
    super.actionsPadding,
    super.leading,
    super.backgroundColor,
    this.titleWidget,
  }) : super(
          title: titleWidget ?? Text(title),
        );
}
