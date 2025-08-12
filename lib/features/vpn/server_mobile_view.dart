import 'package:flutter/material.dart';
import 'package:lantern/features/vpn/server_selection.dart';

import '../../core/common/common.dart';

class ServerMobileView extends StatefulWidget {
  final OnSeverSelected onServerSelected;

  const ServerMobileView({
    super.key,
    required this.onServerSelected,
  });

  @override
  State<ServerMobileView> createState() => _ServerMobileViewState();
}

class _ServerMobileViewState extends State<ServerMobileView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          label: 'Korea',
          icon: AppImagePaths.location,
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: AppColors.gray9,
            size: 20,
          ),
          onPressed: onItemTap,
        ),
        DividerSpace(),
      ],
    );
  }

  void onItemTap() {
    showAppBottomSheet(
      context: context,
      title: 'Korea',
      scrollControlDisabledMaxHeightRatio: .4,
      builder: (context, scrollController) {
        return ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            AppTile(
              label: 'USA - New Jersey',
              trailing: Radio<bool>(
                activeColor: AppColors.gray9,
                value: true,
                groupValue: true,
                onChanged: (value) {},
              ),
            )
          ],
        );
      },
    );
  }
}
