import 'package:device_info_plus/device_info_plus.dart';
import 'package:lantern/core/common/common.dart';

class DeviceUtils {
  static Future<(String, String)> getDeviceAndModel() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (PlatformUtils.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return (info.device, info.model);
    } else if (PlatformUtils.isIOS) {
      final info = await deviceInfo.iosInfo;
      return (info.utsname.machine, info.modelName);
    } else if (PlatformUtils.isLinux) {
      final info = await deviceInfo.linuxInfo;
      return (info.name, info.prettyName);
    } else if (PlatformUtils.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      return (info.osRelease, info.modelName);
    } else {
      final info = await deviceInfo.windowsInfo;
      return (info.computerName, info.computerName);
    }
  }
}
