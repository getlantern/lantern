import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  final EdgeInsets padding;
  final EdgeInsets? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: defaultSize),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? EdgeInsets.zero,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
