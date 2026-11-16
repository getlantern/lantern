import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

/// How often probe results are reloaded while a pinned server is in use.
/// Nothing else refreshes them while the home screen is showing.
@visibleForTesting
const pinnedServerRefreshInterval = Duration(seconds: 30);

/// Tag of the Lantern server the user picked by hand, while the VPN is
/// connected through it. Null in every other state.
final pinnedLanternServerTagProvider = Provider<String?>((ref) {
  if (ref.watch(vpnProvider) != VPNStatus.connected) return null;
  final location = ref.watch(serverLocationProvider);
  if (location.serverType.toServerLocationType !=
      ServerLocationType.lanternLocation) {
    return null;
  }
  return location.serverName;
});

/// True while connected through a hand-picked server whose probes keep
/// failing. Manual selection never fails over, so the user has to be told.
final pinnedServerUnreachableProvider = Provider<bool>((ref) {
  final tag = ref.watch(pinnedLanternServerTagProvider);
  if (tag == null) return false;
  final server = ref.watch(availableServersProvider).value?.serverByTag(tag);
  return server?.isProbedUnreachable ?? false;
});

/// Home screen note that the pinned server has turned unreachable. Tapping it
/// opens the server list.
class PinnedServerWarning extends HookConsumerWidget {
  const PinnedServerWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedTag = ref.watch(pinnedLanternServerTagProvider);
    useEffect(() {
      if (pinnedTag == null) return null;
      final timer = Timer.periodic(pinnedServerRefreshInterval, (_) {
        unawaited(
          ref
              .read(availableServersProvider.notifier)
              .forceFetchAvailableServers(),
        );
      });
      return timer.cancel;
    }, [pinnedTag]);

    if (!ref.watch(pinnedServerUnreachableProvider)) {
      return const SizedBox.shrink();
    }
    final location = ref.watch(
      serverLocationProvider.select((s) => s.displayName),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InfoRow(
        key: const Key('home.pinned_server_unreachable'),
        icon: AppImage(path: AppImagePaths.warning, color: context.borderError),
        text: 'pinned_server_unreachable'.i18n.fill([location]),
        onPressed: () => appRouter.push(const ServerSelection()),
      ),
    );
  }
}
