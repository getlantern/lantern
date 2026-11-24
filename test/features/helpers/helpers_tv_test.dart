import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

void main() {
  tearDown(() {
    PlatformUtils.debugTvShell = null;
    HelpersNotifier.debugBuildEnabled = null;
  });

  test('the TV shell keeps the helper engine locked, like a stealth build', () {
    HelpersNotifier.debugBuildEnabled = true;
    expect(HelpersNotifier.buildEnabled, isTrue);
    PlatformUtils.debugTvShell = true;
    expect(HelpersNotifier.buildEnabled, isFalse);
  });
}
