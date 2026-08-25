import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/home/vpn_tab.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  @override
  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo() async {
    return right(
      DataCapUsageResponse(
        enabled: true,
        usage: DataCapUsageDetails(
          bytesAllotted: 1000,
          bytesUsed: 100,
          allotmentStartTime: '2026-08-25T00:00:00Z',
          allotmentEndTime: '2026-08-26T00:00:00Z',
        ),
      ),
    );
  }

  @override
  Stream<LanternStatus> watchVPNStatus() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('scrolls instead of overflowing at the Windows smoke-test size', (
    tester,
  ) async {
    Localization.translations += await GettextImporter().fromAssetFile(
      'en',
      'assets/locales/en.po',
    );
    Localization.defaultLocale = 'en';
    addTearDown(() => Localization.defaultLocale = 'en_US');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = desktopWindowSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lanternServiceProvider.overrideWithValue(_FakeLanternService()),
          isUserProProvider.overrideWithValue(false),
          isUserExpiredProvider.overrideWithValue(false),
          serverLocationProvider.overrideWithValue(
            initialServerLocation().copyWith(
              autoLocation: const AutoLocation(
                country: '',
                countryCode: '',
                displayName: 'fastest_server',
              ),
            ),
          ),
          radianceSettingsProvider.overrideWithValue(
            const RadianceSettingsState(),
          ),
          vpnProvider.overrideWithValue(VPNStatus.disconnected),
          macosExtensionProvider.overrideWithValue(
            const MacOSExtensionState(SystemExtensionStatus.activated),
          ),
        ],
        child: ScreenUtilInit(
          designSize: desktopWindowSize,
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: 374, height: 569, child: VpnTab()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    final scrollableFinder = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    );
    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
