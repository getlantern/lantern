import 'package:flutter/material.dart';

class CustomAppBar extends AppBar {
  final Widget? titleWidget;

  CustomAppBar({
    super.key,
    required Object title,
    super.actions,
    super.actionsPadding,
    super.leading,
    super.backgroundColor,
    this.titleWidget,
  }) : super(
          title: title.runtimeType == String
              ? Text(title as String)
              : title as Widget,
        );
}
