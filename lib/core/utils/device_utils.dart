import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfo {
  final String device;
  final String model;

  const DeviceInfo({
    required this.device,
    required this.model,
  });
}

class DeviceUtils {
  static Future<DeviceInfo> getDeviceAndModel() async {
    final plugin = DeviceInfoPlugin();
    switch (Platform.operatingSystem) {
      case 'android':
        final info = await plugin.androidInfo;
        return DeviceInfo(
          device: info.manufacturer,
          model: info.model,
        );
      case 'ios':
        final info = await plugin.iosInfo;
        return DeviceInfo(
          device: info.name,
          model: info.utsname.machine,
        );
      case 'macos':
        final info = await plugin.macOsInfo;
        return DeviceInfo(
          device: info.computerName,
          model: info.model,
        );
      case 'windows':
        final info = await plugin.windowsInfo;
        return DeviceInfo(
          device: info.computerName,
          model: info.productName,
        );
      case 'linux':
        final info = await plugin.linuxInfo;
        return DeviceInfo(
          device: info.name,
          model: info.machineId ?? 'unknown',
        );
      default:
        return DeviceInfo(
          device: Platform.operatingSystem,
          model: 'unknown',
        );
    }
  }
}
