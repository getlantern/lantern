import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_tile.dart';

class ProviderCard extends StatelessWidget {
  final String title;
  final String price;
  final VoidCallback onContinue;
  final String icon;

  const ProviderCard({
    super.key,
    required this.title,
    required this.price,
    required this.onContinue,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.only(right: 5),
      elevation: 4,
      shadowColor: AppColors.shadowColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTile(
              icon: icon,
              label: title,
              tileTextStyle: textTheme.titleMedium,
              contentPadding: EdgeInsets.symmetric(horizontal: 4.0),
            ),
            Divider(color: AppColors.gray2),
            CheckmarkTile(
              text: 'handle_configuration'.i18n,
            ),
            CheckmarkTile(text: price),
            CheckmarkTile(text: 'seamless_integration'.i18n),
            CheckmarkTile(
              text: 'choose_location'.i18n,
              trailing:
                  AppIconButton(path: AppImagePaths.info, onPressed: () => {}),
            ),
            CheckmarkTile(
              text: 'one_month_included'.i18n.fill([1]),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'continue_with_do'.i18n, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class CheckmarkTile extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const CheckmarkTile({
    super.key,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppTile(
      icon: AppImagePaths.checkmark,
      label: text,
      trailing: trailing,
      dense: true,
      tileTextStyle: textTheme.bodyMedium,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
    );
  }
}
