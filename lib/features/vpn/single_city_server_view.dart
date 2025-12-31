import 'package:flutter/material.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/features/vpn/server_selection.dart';

import '../../core/common/common.dart';

// single_city_server_view.dart

class SingleCityServerView extends StatefulWidget {
  final Location_ location;
  final OnServerSelected onServerSelected;
  final bool isSelected;

  const SingleCityServerView({
    super.key,
    required this.onServerSelected,
    required this.location,
    this.isSelected = false,
  });

  @override
  State<SingleCityServerView> createState() => _SingleCityServerViewState();
}

class _SingleCityServerViewState extends State<SingleCityServerView> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppTile(
      label: '${widget.location.country} - ${widget.location.city}',
      selected: widget.isSelected,
      subtitle: widget.location.protocol.isEmpty
          ? null
          : Text(
              widget.location.protocol.capitalize,
              style: textTheme.labelMedium!.copyWith(
                color: AppColors.gray7,
              ),
            ),
      icon: Flag(countryCode: widget.location.countryCode),
      onPressed: () {
        widget.onServerSelected(widget.location);
      },
    );
  }
}
