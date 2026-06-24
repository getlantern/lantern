import 'package:flutter/material.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/features/vpn/server_selection.dart';

import '../../core/common/common.dart';

// single_city_server_view.dart

class SingleCityServerView extends StatefulWidget {
  final Server server;
  final OnServerSelected onServerSelected;
  final bool isSelected;
  final bool nested;

  /// Whether to surface the "may be unreachable" warning icon. Disabled for
  /// free users, who see every location without the reachability distinction.
  final bool showReachabilityWarning;

  const SingleCityServerView({
    super.key,
    required this.onServerSelected,
    required this.server,
    this.isSelected = false,
    this.nested = false,
    this.showReachabilityWarning = true,
  });

  @override
  State<SingleCityServerView> createState() => _SingleCityServerViewState();
}

class _SingleCityServerViewState extends State<SingleCityServerView> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppTile(
      label: widget.nested
          ? widget.server.location.city
          : '${widget.server.location.country} - ${widget.server.location.city}',
      selected: widget.isSelected,
      subtitle: widget.server.type.isEmpty
          ? null
          : Text(
              widget.server.type.capitalize,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium!.copyWith(
                color: context.textTertiary,
              ),
            ),
      trailing: !widget.showReachabilityWarning
          ? null
          : widget.server.isProbedUnreachable
          ? const ServerReachabilityWarningIcon()
          : null,
      icon: Flag(countryCode: widget.server.location.countryCode),
      onPressed: () {
        widget.onServerSelected(widget.server);
      },
    );
  }
}
