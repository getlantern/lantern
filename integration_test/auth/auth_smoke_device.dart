import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android device codename (Build.DEVICE) that runs the auth suite when several
/// devices run it at once against the same smoke accounts, as Firebase Test Lab
/// does. Empty runs it on every device.
const _authSmokeDevice = String.fromEnvironment('AUTH_SMOKE_DEVICE');

/// Marks the current test skipped on every device but [_authSmokeDevice], and
/// returns whether it did so the caller can stop.
Future<bool> skipUnlessAuthSmokeDevice() async {
  if (_authSmokeDevice.isEmpty || !Platform.isAndroid) return false;
  final device = (await DeviceInfoPlugin().androidInfo).device;
  if (device == _authSmokeDevice) return false;
  markTestSkipped('Auth smoke accounts run on $_authSmokeDevice only');
  return true;
}
