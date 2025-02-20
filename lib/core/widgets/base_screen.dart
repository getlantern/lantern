import 'package:flutter/material.dart';

import '../common/common.dart';

class BaseScreen extends StatelessWidget {
  final String title;

  final Widget body;

  final bool padded;

  const BaseScreen({
    super.key,
    required this.title,
    required this.body,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: title),
      body: Padding(
        padding: padded ? defaultPadding : EdgeInsets.zero,
        child: body,
      ),
    );
  }
}
