import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/vpn/personal_proxies_section.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import '../../core/common/common.dart';

class LocationSetting extends HookConsumerWidget {
  const LocationSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverLocation = ref.watch(serverLocationProvider);
    final serverType = serverLocation.serverType.toServerLocationType;
    final connected = ref.watch(vpnProvider) == VPNStatus.connected;
    usePersonalProxyStatusPoll(
      ref,
      enabled: connected && serverLocation.personalProxyFriendTag != null,
    );

    String title = '';
    String value = '';
    String flag = '';
    String protocol = '';
    String? note;
    Color? noteColor;
    // A friend's name is shown as typed, never looked up as a string key.
    var translate = true;

    switch (serverType) {
      case ServerLocationType.auto:
        title = 'smart_location'.i18n;
        final autoLoc = serverLocation.autoLocation;

        value = autoLoc != null && autoLoc.displayName.isNotEmpty
            ? autoLoc.displayName
            : 'fastest_server'.i18n;

        flag = autoLoc?.countryCode ?? '';
        protocol = autoLoc?.protocol ?? '';
        break;

      case ServerLocationType.lanternLocation:
        title = 'selected_location'.i18n;
        value = serverLocation.displayName;
        flag = serverLocation.countryCode;
        protocol = serverLocation.protocol;
        break;

      case ServerLocationType.privateServer:
        title = serverLocation.serverName;
        value = serverLocation.displayName;
        flag = serverLocation.countryCode;
        protocol = serverLocation.protocol;
        break;

      // Never a flag or a place: the generic location icon, the group's or
      // the selected friend's name, and "Personal Proxy" under it.
      case ServerLocationType.personalProxy:
        title = 'selected_location'.i18n;
        final friend = serverLocation.personalProxyFriendTag;
        if (friend == null) {
          value = 'your_personal_proxies'.i18n;
        } else {
          value = personalProxyFriendName(ref, friend);
          translate = false;
          final status = ref.watch(personalProxyStatusProvider);
          if (connected) {
            (note, noteColor) = _friendPath(context, status?[friend]);
          }
        }
        protocol = 'personal_proxy'.i18n;
        break;
    }

    return SettingTile(
      tileKey: const Key('home.location_setting'),
      label: title,
      value: translate ? value.i18n : value,
      subtitle: protocol,
      note: note,
      noteColor: noteColor,
      icon: flag.isEmpty ? AppImagePaths.location : Flag(countryCode: flag),
      // Small screens drop the > chevron; the row stays tappable via onTap.
      actions: [
        if (serverType == ServerLocationType.auto)
          AppImage(path: AppImagePaths.blot, useThemeColor: false),
        if (!isSmallScreen(context)) ...[
          const SizedBox(width: 8),
          const AppImage(path: AppImagePaths.arrowForward),
        ],
      ],
      onTap: () => appRouter.push(const ServerSelection()),
    );
  }
}

/// The line under a friend selected on their own for their rooms path, while
/// it is not up: nothing while it is connected, can't be measured, or
/// radiance has not said. Nothing either while the friend has a direct or
/// reverse route, which carries their traffic whatever the rooms path does.
(String?, Color?) _friendPath(
  BuildContext context,
  PersonalProxyStatus? status,
) => switch (status) {
  PersonalProxyStatus(direct: true) ||
  PersonalProxyStatus(reverse: true) => (null, null),
  PersonalProxyStatus(roomsConnecting: true) => (
    'personal_proxy_path_connecting'.i18n,
    null,
  ),
  PersonalProxyStatus(roomsReconnecting: true) => (
    'personal_proxy_path_reconnecting'.i18n,
    null,
  ),
  PersonalProxyStatus(roomsUnavailable: true) => (
    'personal_proxy_path_unavailable'.i18n,
    context.statusErrorText,
  ),
  _ => (null, null),
};
