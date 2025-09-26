import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../common/common.dart';
import '../services/injection_container.dart';

class UserDevices extends HookConsumerWidget {
  // final List<UserResponse_Device> userDevices;
  // final String myDeviceId;

  const UserDevices({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeNotifierProvider).value;
    if (user == null) {
      return const SizedBox();
    }
    final userDevices = user.legacyUserData.devices.toList();
    final myDeviceId = user.legacyUserData.deviceID ?? '';

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
          return _buildRow(e, ref, context,myDeviceId != e.name);
        },
      ),
    );
  }

  Widget _buildRow(UserResponse_Device e, WidgetRef ref, BuildContext context,bool isMyDevice) {
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
      UserResponse_Device device, WidgetRef ref, BuildContext context) async {
    context.showLoadingDialog();
    final result =
        await ref.read(authNotifierProvider.notifier).deviceRemove(device.id);

    result.fold((failure) {
      context.showSnackBar(failure.localizedErrorMessage);
    }, (success) async {
      context.showSnackBar('device_removed'.i18n);
      final innerResult =
          await ref.read(homeNotifierProvider.notifier).fetchUserData();
      context.hideLoadingDialog();
    });
  }
}
