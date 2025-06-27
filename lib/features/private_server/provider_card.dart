import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/server_locations.dart';

class ProviderCard extends StatelessWidget {
  final String title;
  final CloudProvider provider;
  final String price;
  final VoidCallback onContinue;
  final String icon;

  const ProviderCard({
    super.key,
    required this.title,
    required this.provider,
    required this.price,
    required this.onContinue,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    void showServerLocationsModal() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).canvasColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => provider == CloudProvider.googleCloud
            ? GoogleCloudLocations()
            : DigitalOceanLocations(),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AppTile(
            icon: icon,
            label: title,
            dense: true,
            tileTextStyle: textTheme.titleMedium,
            contentPadding: EdgeInsets.symmetric(horizontal: 4.0),
          ),
          Divider(color: AppColors.gray2),
          CheckmarkTile(text: 'handle_configuration'.i18n),
          CheckmarkTile(text: price),
          CheckmarkTile(text: 'seamless_integration'.i18n),
          CheckmarkTile(
            text: 'choose_location'.i18n,
            trailing: AppIconButton(
              path: AppImagePaths.info,
              onPressed: () => showServerLocationsModal(),
            ),
          ),
          CheckmarkTile(
            text: 'one_month_included'.i18n.fill([1]),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
              label: '${'continue_with'.i18n} ${provider.displayName}',
              onPressed: onContinue),
        ],
    final providerName = provider.value;

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
              trailing: AppIconButton(
                path: AppImagePaths.info,
                onPressed: () => showServerLocationsModal(),
              ),
            ),
            CheckmarkTile(
              text: 'one_month_included'.i18n.fill([1]),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
                label: 'continue_with_$providerName'.i18n, onPressed: () {}),
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
