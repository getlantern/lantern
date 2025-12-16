import 'package:flutter/material.dart';
import 'package:lantern/features/vpn/server_selection.dart';

import '../../core/common/common.dart';

class ServerDesktopView extends StatefulWidget {
  final OnServerSelected onServerSelected;

  const ServerDesktopView({
    super.key,
    required this.onServerSelected,
  });

  @override
  State<ServerDesktopView> createState() => _ServerDesktopViewState();
}

class _ServerDesktopViewState extends State<ServerDesktopView> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExpansionTile(
          enableFeedback: true,
          onExpansionChanged: _onTileStateChange,
          trailing: AnimatedRotation(
            duration: Duration(milliseconds: 200),
            turns: isExpanded ? .25 : 0.0,
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.gray9,
              size: 20,
            ),
          ),
          title: Text(
            'Korea',
            style: textTheme.bodyLarge!.copyWith(color: AppColors.gray9),
          ),
          shape: RoundedRectangleBorder(side: BorderSide.none),
          leading: AppImage(path: AppImagePaths.location),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            AppTile(
              contentPadding: EdgeInsets.only(left: 46),
              label: 'USA - New Jersey',
              tileTextStyle:
                  textTheme.bodyMedium!.copyWith(color: AppColors.gray9),
              trailing: Radio<bool>(
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.gray9,
                value: true,
                groupValue: false,
                onChanged: (value) {},
              ),
              onPressed: () => onServerTap(),
            )
          ],
        ),
        DividerSpace(),
      ],
    );
  }

  void _onTileStateChange(bool value) {
    setState(() {
      isExpanded = value;
    });
  }

  void onServerTap() {
    // widget.onServerSelected('Korea');
  }
}
