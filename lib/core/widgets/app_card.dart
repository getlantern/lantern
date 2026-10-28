import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color? bgColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: defaultSize),
    this.margin,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bgColor,
      margin: margin ?? EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
  }
}
