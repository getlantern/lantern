import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one Android device that runs the auth suite when several run it at
/// once against the same smoke accounts, as Firebase Test Lab does:
/// `<Build.DEVICE>` or `<Build.DEVICE>@<API level>`. Empty runs it on every
/// device.
const _authSmokeDevice = String.fromEnvironment('AUTH_SMOKE_DEVICE');

/// Marks the current test skipped on every device but [_authSmokeDevice], and
/// returns whether it did so the caller can stop.
Future<bool> skipUnlessAuthSmokeDevice() async {
  if (_authSmokeDevice.isEmpty || !Platform.isAndroid) return false;
  final [device, ...sdk] = _authSmokeDevice.split('@');
  final info = await DeviceInfoPlugin().androidInfo;
  if (info.device == device &&
      (sdk.isEmpty || info.version.sdkInt.toString() == sdk.single)) {
    return false;
  }
  markTestSkipped('Auth smoke accounts run on $_authSmokeDevice only');
  return true;
}
