import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/core/widgets/app_focusable.dart';
import 'package:lantern/core/widgets/switch_button.dart';

void main() {
  tearDown(() {
    PlatformUtils.isTv = false;
    PlatformUtils.debugTvShell = null;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(960, 540),
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: SwitchButton(value: false, onChanged: (_) {})),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('in the TV shell the knob has equal padding and the ring room', (
    tester,
  ) async {
    PlatformUtils.isTv = true;
    PlatformUtils.debugTvShell = true;
    await pump(tester);
    final track = tester.getSize(find.byType(CustomAnimatedToggleSwitch<bool>));
    expect(track.height, 40, reason: '30 knob plus 5 above and below');
    final ring = tester.getSize(find.byType(AppFocusable));
    expect(ring.height, track.height + 16, reason: '8 around for the ring');
    expect(ring.width, track.width + 16);
  });

  testWidgets('elsewhere the switch is as it was', (tester) async {
    await pump(tester);
    final track = tester.getSize(find.byType(CustomAnimatedToggleSwitch<bool>));
    final ring = tester.getSize(find.byType(AppFocusable));
    expect(ring, track, reason: 'the ring is drawn over the track');
  });
}
