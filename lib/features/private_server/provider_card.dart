import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class ProviderCard extends StatelessWidget {
  final String title;
  final CloudProvider provider;
  final String icon;
  final VoidCallback onContinueClicked;
  final String buttonTitle;
  final List<String> features;

  const ProviderCard({
    super.key,
    required this.title,
    required this.buttonTitle,
    required this.features,
    required this.provider,
    required this.icon,
    required this.onContinueClicked,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 32,
          offset: Offset(0, 4),
          spreadRadius: 0,
        )
      ]),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: defaultSize),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppImage(path: icon, width: 20, height: 20),
                const SizedBox(width: defaultSize),
                Expanded(
                  child: Text(
                    title,
                    style: t.titleMedium?.copyWith(
                      color: AppColors.black1,
                      fontWeight: FontWeight.w600,
                      // height: 1.50,
                    ),
                  ),
                ),
              ],
            ),
            DividerSpace(padding: EdgeInsets.symmetric(vertical: 8)),
            const SizedBox(height: 8),
            ...features.map((e) => CheckmarkTile(
                  text: e,
                  showDivider: false,
                )),
            Spacer(),
            PrimaryButton(
                label: buttonTitle,
                isTaller: true,
                onPressed: onContinueClicked),
            SizedBox(height: defaultSize),
          ],
        ),
      ),
    );
  }
}

class CheckmarkTile extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final String? iconPath;
  final bool showDivider;
  final double topPadding;
  final double bottomPadding;

  const CheckmarkTile({
    super.key,
    required this.text,
    this.trailing,
    this.iconPath,
    this.showDivider = false,
    this.topPadding = 8,
    this.bottomPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final row = Semantics(
      label: text,
      readOnly: true,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppImage(
              path: iconPath ?? AppImagePaths.checkmark,
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: t.bodyMedium?.copyWith(
                  color: AppColors.black1,
                  height: 1.64,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (!showDivider) return row;

    return Column(
      children: [
        row,
        Divider(height: 1, color: AppColors.gray2),
      ],
    );
  }
}
