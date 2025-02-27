import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  final EdgeInsets padding;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: defaultSize),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
