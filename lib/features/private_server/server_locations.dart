import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/bullet_list.dart';

class DigitalOceanLocations extends StatelessWidget {
  const DigitalOceanLocations({super.key});

  @override
  Widget build(BuildContext context) {
    final doLocations = <String>[
      'Australia – Sydney',
      'Canada – Toronto',
      'Germany – Frankfurt',
      'India – Bangalore',
      'Netherlands – Amsterdam',
      'Singapore – Singapore',
      'United Kingdom – London',
      'United States – New York City',
      'United States – San Francisco',
    ];

    return ServerLocationsModal(
      leadingIcon: AppImage(
        path: AppImagePaths.digitalOcean,
      ),
      locations: doLocations,
      description: 'digital_ocean_allows'.i18n.fill([doLocations.length]),
    );
  }
}

class GoogleCloudLocations extends StatelessWidget {
  const GoogleCloudLocations({super.key});

  @override
  Widget build(BuildContext context) {
    // TEST DATA. TODO: Populate with actual GCP and DO locations
    const List<String> gcpLocations = [
      'Australia – Melbourne',
      'Australia – Sydney',
      'Belgium – St. Ghislain',
      'Brazil – São Paulo',
      'Canada – Montreal',
      'Canada – Toronto',
      'Finland – Hamina',
      'Germany – Frankfurt',
      'Hong Kong – Hong Kong',
      'India – Delhi',
      'India – Mumbai',
      'Indonesia – Jakarta',
      'Japan – Osaka',
      'Japan – Tokyo',
      'Netherlands – Eemshaven',
      'Poland – Warsaw',
      'Singapore – Jurong West',
      'South Korea – Seoul',
      'Switzerland – Zurich',
      'Taiwan – Changhua County',
      'United Kingdom – London',
      'United States – Iowa',
      'United States – Las Vegas',
      'United States – Los Angeles',
      'United States – Northern Virginia',
      'United States – Oregon',
      'United States – Salt Lake City',
      'United States – South Carolina',
    ];
    return ServerLocationsModal(
      leadingIcon: AppImage(
        path: AppImagePaths.googleCloud,
      ),
      locations: gcpLocations,
      description: 'google_cloud_allows'.i18n.fill([gcpLocations.length]),
    );
  }
}

class ServerLocationsModal extends StatelessWidget {
  final Widget leadingIcon;
  final String description;
  final List<String> locations;

  const ServerLocationsModal({
    Key? key,
    required this.leadingIcon,
    required this.locations,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leadingIcon,
            const SizedBox(height: defaultSize),
            Text(
              'server_locations'.i18n,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: defaultSize),
            Text(
              description,
              style: AppTestStyles.bodyMedium,
            ),
            const SizedBox(height: defaultSize),
            BulletList(items: locations),
            const SizedBox(height: defaultSize),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'got_it'.i18n,
                  style: AppTestStyles.titleMedium.copyWith(
                    color: AppColors.blue6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
