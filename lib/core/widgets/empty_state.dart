import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// An empty tab or list: an icon, a heading (Heading/Small), one line of
/// body (Body/Large, text/tertiary), all centred, and one full-width primary
/// button that leads to the screen where the first item is made.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    this.buttonKey,
  });

  /// An asset path, drawn 40 px in text/primary.
  final String icon;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 48, bottom: defaultSize),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: AppImage(
              path: icon,
              width: 40,
              height: 40,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: defaultSize),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall!.copyWith(
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge!.copyWith(color: context.textTertiary),
          ),
          const SizedBox(height: size24),
          PrimaryButton(
            buttonKey: buttonKey,
            label: buttonLabel,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
