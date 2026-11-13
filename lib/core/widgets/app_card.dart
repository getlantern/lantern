import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color? bgColor;

  /// Lifts the card with the app's card shadow, as the VPN tab's cards are.
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: defaultSize),
    this.margin,
    this.bgColor,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: bgColor,
      margin: margin ?? EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
    if (!shadow) return card;
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 32,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: card,
    );
  }
}
