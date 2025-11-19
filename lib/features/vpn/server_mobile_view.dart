import 'package:flutter/material.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/utils/country_utils.dart';
import 'package:lantern/features/vpn/server_selection.dart';

import '../../core/common/common.dart';

class ServerMobileView extends StatefulWidget {
  final Location_ location;
  final OnSeverSelected onServerSelected;
  final bool isSelected;

  const ServerMobileView({
    super.key,
    required this.onServerSelected,
    required this.location,
    this.isSelected = false,
  });

  @override
  State<ServerMobileView> createState() => _ServerMobileViewState();
}

class _ServerMobileViewState extends State<ServerMobileView> {
  @override
  Widget build(BuildContext context) {
    return AppTile(
      label: widget.location.city,
      selected: widget.isSelected,

      icon: Flag(
        countryCode: CountryUtils.getCountryCode(widget.location.country),
      ),
      onPressed: () {
        widget.onServerSelected(widget.location);
      },
    );
  }

}
