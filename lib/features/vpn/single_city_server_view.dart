import 'package:flutter/material.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/features/vpn/server_selection.dart';

import '../../core/common/common.dart';

// single_city_server_view.dart

class SingleCityServerView extends StatefulWidget {
  final Location_ location;
  final OnServerSelected onServerSelected;
  final bool isSelected;
  final bool nested;
  final bool showSmartProtocol;

  const SingleCityServerView({
    super.key,
    required this.onServerSelected,
    required this.location,
    this.isSelected = false,
    this.nested = false,
    this.showSmartProtocol = false,
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
          ? widget.location.city
          : '${widget.location.country} - ${widget.location.city}',
      selected: widget.isSelected,
      subtitle: _protocolSubtitle(textTheme),
      icon: Flag(countryCode: widget.location.countryCode),
      onPressed: () {
        widget.onServerSelected(widget.location);
      },
    );
  }

  Widget? _protocolSubtitle(TextTheme textTheme) {
    final protocol = widget.location.protocol;
    final label = protocol.isNotEmpty
        ? protocol.capitalize
        : widget.showSmartProtocol
            ? 'smart_protocol'.i18n
            : null;
    if (label == null) return null;
    return Text(
      label,
      style: textTheme.labelMedium!.copyWith(
        color: context.textTertiary,
      ),
    );
  }
}
