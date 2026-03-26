import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/core/models/user.dart';

import '../common/common.dart';

class UserDevices extends HookConsumerWidget {
  // final List<DeviceModel> userDevices;
  // final String myDeviceId;

  const UserDevices({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeProvider).value;
    if (user == null) {
      return const SizedBox();
    }
    final userDevices = user.legacyUserData.devices.toList();
    final myDeviceId = user.legacyUserData.deviceID;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: userDevices.length,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (context, index) => const DividerSpace(),
        itemBuilder: (context, index) {
          final e = userDevices[index];
          return _buildRow(e, ref, context, myDeviceId != e.name);
        },
      ),
    );
  }

  Widget _buildRow(DeviceModel e, WidgetRef ref, BuildContext context,
      bool isMyDevice) {
    return AppTile(
      label: e.name,
      contentPadding: EdgeInsets.only(left: 16),
      trailing: isMyDevice
          ? AppTextButton(
              label: 'remove'.i18n,
              onPressed: () => _removeDevice(e, ref, context),
            )
          : null,
    );
  }

  Future<void> _removeDevice(
      DeviceModel device, WidgetRef ref, BuildContext context) async {
    context.showLoadingDialog();
    final result =
        await ref.read(authProvider.notifier).deviceRemove(device.deviceId);

    result.fold((failure) {
      context.showSnackBar(failure.localizedErrorMessage);
    }, (success) async {
      context.showSnackBar('device_removed'.i18n);
      final innerResult = await ref.read(homeProvider.notifier).fetchUserData();
      context.hideLoadingDialog();
    });
  }
}
