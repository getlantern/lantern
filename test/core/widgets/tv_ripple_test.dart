import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/setting_tile.dart';

/// The focus-ring-shaped ripple is the TV shell's; the phone keeps its own.
void main() {
  tearDown(() {
    PlatformUtils.isTv = false;
    PlatformUtils.debugTvShell = null;
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proRenewalProvider.overrideWithValue(ProRenewalInfo.none),
          isUserProProvider.overrideWithValue(false),
          isUserExpiredProvider.overrideWithValue(false),
        ],
        child: ScreenUtilInit(
          designSize: mobileSize,
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  BorderRadius? radiusIn(WidgetTester tester, Type widget) => tester
      .widget<InkWell>(
        find.descendant(of: find.byType(widget), matching: find.byType(InkWell)),
      )
      .borderRadius;

  for (final tv in [false, true]) {
    testWidgets('SettingTile ripple radius ${tv ? 'set on TV' : 'null off TV'}', (
      tester,
    ) async {
      PlatformUtils.isTv = tv;
      PlatformUtils.debugTvShell = tv;
      await pump(
        tester,
        SettingTile(
          label: 'Routing',
          value: 'Smart',
          icon: const Icon(Icons.route),
          actions: const [],
          onTap: () {},
        ),
      );
      expect(
        radiusIn(tester, SettingTile),
        tv ? BorderRadius.circular(16) : isNull,
      );
    });

    testWidgets('compact ProBanner ripple radius ${tv ? 'set on TV' : 'null off TV'}', (
      tester,
    ) async {
      PlatformUtils.isTv = tv;
      PlatformUtils.debugTvShell = tv;
      await pump(tester, const ProBanner());
      expect(
        radiusIn(tester, ProBanner),
        tv ? BorderRadius.circular(9999) : isNull,
      );
    });
  }
}
