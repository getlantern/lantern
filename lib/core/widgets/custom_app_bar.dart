import 'package:flutter/material.dart';

class CustomAppBar extends AppBar {
  CustomAppBar({
    super.key,
    required String title,
    super.actions,
    super.actionsPadding,
    super.leading,
    super.backgroundColor,

  }) : super(
          title: Text(title),
        );
}
