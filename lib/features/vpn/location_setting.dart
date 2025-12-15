import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';

import '../../core/common/common.dart';

class LocationSetting extends HookConsumerWidget {
  const LocationSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverLocation = ref.watch(serverLocationProvider);
    final serverType = serverLocation.serverType.toServerLocationType;
    String? title, value,flag = '';

    switch (serverType) {
      case ServerLocationType.auto:
        title = 'smart_location'.i18n;
        value = serverLocation.displayName.isNotEmpty
            ? serverLocation.displayName
            : serverLocation.autoLocation!.country;
        flag = serverLocation.autoLocation?.countryCode??'';
        break;
      case ServerLocationType.lanternLocation:
        title = 'selected_location'.i18n;
        value = serverLocation.displayName;
        flag = serverLocation.countryCode;
        break;
      case ServerLocationType.privateServer:
        title = serverLocation.serverName;
        value = serverLocation.displayName;
        flag = serverLocation.countryCode;
        break;
    }
    return SettingTile(
      label: title,
      value: value,
      icon: flag.isEmpty
          ? AppImagePaths.location
          : Flag(countryCode: flag),
      actions: [
        if (serverType == ServerLocationType.auto)
          AppImage(path: AppImagePaths.blot),
        SizedBox(width: 8),
        IconButton(
          onPressed: () {
            appRouter.push(const ServerSelection());
          },
          style: ElevatedButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: AppImage(path: AppImagePaths.verticalDots),
          padding: EdgeInsets.zero,
          // iconSize: 10,
          constraints: BoxConstraints(),
          visualDensity: VisualDensity.compact,
        )
      ],
      onTap: () {
        appRouter.push(const ServerSelection());
      },
    );
  }
}
