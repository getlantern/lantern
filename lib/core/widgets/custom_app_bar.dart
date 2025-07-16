import 'package:flutter/material.dart';

class CustomAppBar extends AppBar {
  CustomAppBar({
    super.key,
    required Object title,
    super.actions,
    super.actionsPadding,
    super.leading,
    super.backgroundColor,
  }) : super(
          title: title.runtimeType == String
              ? Text(title as String)
              : title as Widget,
        );
}
