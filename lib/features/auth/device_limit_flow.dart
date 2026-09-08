import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/user.dart';

/// Shows the device-removal screen for an account that hit its device limit.
///
/// If the user removed a device, waits for the backend to propagate the
/// removal (retrying immediately may still hit the device limit) and then
/// invokes [onRemoved].
Future<void> startDeviceLimitFlow(
  List<DeviceModel> devices,
  Future<void> Function() onRemoved,
) async {
  final removed = await appRouter.push(DeviceLimitReached(devices: devices));
  if (removed != true) return;
  await Future.delayed(const Duration(seconds: 1));
  await onRemoved();
}
