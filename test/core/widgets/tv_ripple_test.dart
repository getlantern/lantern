import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/setting_tile.dart';

/// The rows' ripples are rounded the same everywhere: the TV focus ring
/// wraps them without changing the shape the phone had.
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

  const modes = {
    'phone': (tv: false, shell: false),
    'TV without the shell': (tv: true, shell: false),
    'TV shell': (tv: true, shell: true),
  };

  for (final MapEntry(key: name, value: mode) in modes.entries) {
    testWidgets('SettingTile keeps its 16dp ripple radius on $name', (
      tester,
    ) async {
      PlatformUtils.isTv = mode.tv;
      PlatformUtils.debugTvShell = mode.shell;
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
      expect(radiusIn(tester, SettingTile), BorderRadius.circular(16));
    });

    testWidgets('the compact ProBanner keeps its pill ripple radius on $name', (
      tester,
    ) async {
      PlatformUtils.isTv = mode.tv;
      PlatformUtils.debugTvShell = mode.shell;
      await pump(tester, const ProBanner());
      expect(radiusIn(tester, ProBanner), BorderRadius.circular(9999));
    });
  }
}
