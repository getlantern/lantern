import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/base_screen.dart';

@RoutePage(name: 'VPNSetting')
class VPNSetting extends StatelessWidget {
  const VPNSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'vpn_setting'.i18n, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          AppTile(
            label: 'split_tunneling'.i18n,
            icon: AppImagePaths.callSpilt,
            trailing: Text(
              'Enabled',
              style: textTheme.titleMedium!.copyWith(
                color: AppColors.blue7,
              ),
            ),
            onPressed: () {},
          ),
          DividerSpace(),
          AppTile(
            label: 'server_locations'.i18n,
            icon: AppImagePaths.location,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
