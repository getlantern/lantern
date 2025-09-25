import 'package:flutter/material.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../common/common.dart';

class UserDevices extends StatelessWidget {
  final List<UserResponse_Device> userDevices;

  const UserDevices({
    super.key,
    required this.userDevices,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ...userDevices.map((e) => _buildRow(e)),
          DividerSpace(),
          // Padding(
          //   padding: const EdgeInsets.symmetric(vertical: 5),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.end,
          //     children: [
          //       AppTextButton(
          //         label: 'add_device'.i18n,
          //         onPressed: () {},
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildRow(UserResponse_Device e) {
    return AppTile(
      label: e.name,
      contentPadding: EdgeInsets.only(left: 16),
      // icon: AppImagePaths.email,
      // trailing: AppTextButton(label: 'remove'.i18n, onPressed: () {}),
      // onPressed: () {},
    );
  }
}
