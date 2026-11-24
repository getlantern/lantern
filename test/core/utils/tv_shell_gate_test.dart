import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/utils/platform_utils.dart';

void main() {
  tearDown(() {
    PlatformUtils.isTv = false;
    PlatformUtils.debugTvShell = null;
  });

  test('the TV shell is off without the TV_SHELL build define', () {
    expect(AppBuildInfo.tvShell, isFalse, reason: 'tests build without it');
    PlatformUtils.isTv = true;
    expect(PlatformUtils.tvShellEnabled, isFalse);
  });

  test('the TV shell is off on every non-TV device', () {
    PlatformUtils.isTv = false;
    expect(PlatformUtils.tvShellEnabled, isFalse);
  });

  test('tests can force the shell on or off', () {
    PlatformUtils.debugTvShell = true;
    expect(PlatformUtils.tvShellEnabled, isTrue);
    PlatformUtils.debugTvShell = false;
    PlatformUtils.isTv = true;
    expect(PlatformUtils.tvShellEnabled, isFalse);
  });
}
