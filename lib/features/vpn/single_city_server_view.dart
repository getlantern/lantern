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

  const SingleCityServerView({
    super.key,
    required this.onServerSelected,
    required this.server,
    this.isSelected = false,
    this.nested = false,
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
              style: textTheme.labelMedium!.copyWith(
                color: context.textTertiary,
              ),
            ),
      icon: Flag(countryCode: widget.server.location.countryCode),
      onPressed: () {
        widget.onServerSelected(widget.server);
      },
    );
  }
}
