import 'package:flutter/material.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/latency_status.dart';
import 'package:lantern/features/vpn/latency_indicator.dart';

import '../../core/common/common.dart';

class SingleCityServerView extends StatelessWidget {
  final Server server;
  final ValueChanged<Server> onServerSelected;
  final bool isSelected;
  final bool nested;

  const SingleCityServerView({
    super.key,
    required this.onServerSelected,
    required this.server,
    this.isSelected = false,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final location = server.location;
    final status = LatencyStatus.of(server);
    return AppTile(
      label: nested ? location.city : '${location.country} - ${location.city}',
      selected: isSelected,
      subtitle: server.type.isEmpty
          ? null
          : Text(
              server.type.capitalize,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium!.copyWith(color: context.textTertiary),
            ),
      icon: Flag(countryCode: location.countryCode),
      trailing: LatencyTrailing(status: status),
      onPressed: () => onServerSelected(server),
    );
  }
}
