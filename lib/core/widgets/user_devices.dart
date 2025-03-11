import 'package:flutter/material.dart';

import '../common/common.dart';

class UserDevices extends StatelessWidget {
  const UserDevices({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildRow(),
          DividerSpace(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppTextButton(
                  label: 'add_device'.i18n,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow() {
    return AppTile(
      label: 'Samsung Galaxy',
      contentPadding: EdgeInsets.only(left: 16),
      icon: AppImagePaths.email,
      trailing: AppTextButton(label: 'remove'.i18n, onPressed: () {}),
      onPressed: () {},
    );
  }
}
