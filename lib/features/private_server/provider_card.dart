import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class ProviderCard extends StatelessWidget {
  final String title;
  final CloudProvider provider;
  final String price;
  final String icon;
  final VoidCallback? onShowLocations;

  const ProviderCard({
    super.key,
    required this.title,
    required this.provider,
    required this.price,
    required this.icon,
    this.onShowLocations,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray2, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 32,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: AppImage(path: icon, width: 24, height: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: t.titleMedium?.copyWith(
                    color: AppColors.black1,
                    fontWeight: FontWeight.w600,
                    height: 1.50,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.gray2),
          CheckmarkTile(
            text: 'handle_configuration'.i18n,
            showDivider: true,
          ),
          CheckmarkTile(
            text: price,
            showDivider: true,
          ),
          CheckmarkTile(
            text: 'seamless_integration'.i18n,
            showDivider: true,
          ),
          CheckmarkTile(
            text: 'choose_location'.i18n,
            trailing: Semantics(
              button: true,
              label: 'choose_location'.i18n,
              child: AppIconButton(
                path: AppImagePaths.info,
                onPressed: onShowLocations,
              ),
            ),
            showDivider: false,
          ),
          CheckmarkTile(
            text: 'one_month_included'.i18n.fill([1]),
            showDivider: false,
            topPadding: 8,
          ),
        ],
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
