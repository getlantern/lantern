import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

import '../../lantern/protos/protos/auth.pb.dart';

@RoutePage(name: 'DeviceLimitReached')
class DeviceLimitReached extends HookConsumerWidget {
  final List<UserResponse_Device> devices;

  const DeviceLimitReached({
    super.key,
    required this.devices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final selectedDevice = useState<UserResponse_Device?>(null);
    return BaseScreen(
      title: 'device_limit_reached'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: defaultSize),
          Text(
            'device_limit_reached_message'.i18n,
            style: textTheme.bodyMedium,
          ),
          SizedBox(height: 24.0),
          Text("lantern_pro_devices".i18n,
              style: textTheme.labelLarge!.copyWith(
                color: AppColors.gray8,
              )),
          AppCard(
              child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(0),
            children: devices.map((device) {
              return AppTile(
                label: device.name,
                trailing: AppRadioButton(
                  value: device,
                  groupValue: selectedDevice,
                ),
              );
            }).toList(),
          )),
          SizedBox(height: 32.0),
          PrimaryButton(
            label: 'remove_device_and_sign_in'.i18n,
            enabled: selectedDevice.value != null,
            onPressed: () =>
                removeDeviceAndLogin(ref, selectedDevice.value!.id, context),
          ),
          SizedBox(height: 30.0),
          Center(
            child: AppTextButton(
              label: 'cancel_sign_in'.i18n,
              textColor: AppColors.gray9,
              onPressed: () {
                appRouter.pop(context);
              },
            ),
          )
        ],
      ),
    );
  }

  Future<void> removeDeviceAndLogin(
      WidgetRef ref, String deviceId, BuildContext context) async {
    final result =
        await ref.read(lanternServiceProvider).deviceRemove(deviceId: deviceId);
    result.fold(
      (failure) {
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (message) {
        appRouter.pop(true);
      },
    );
  }
}
