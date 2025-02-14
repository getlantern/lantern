import 'package:flutter/material.dart';

class CustomAppBar extends AppBar {

  CustomAppBar({super.key, required String title})
      : super(
          title: Text(title),
        );
}
