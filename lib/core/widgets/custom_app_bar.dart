import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget {

  final String title;

  const CustomAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
    );
  }
}
