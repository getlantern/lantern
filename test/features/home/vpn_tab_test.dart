import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/extensions/ref.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/home/vpn_tab.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  @override
  Stream<LanternStatus> watchVPNStatus() => const Stream.empty();

  @override
  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo() async => right(
    DataCapUsageResponse(
      enabled: true,
      usage: DataCapUsageDetails(
        bytesAllotted: 256000000,
        bytesUsed: 0,
        allotmentStartTime: '',
        allotmentEndTime: '',
      ),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('free VPN tab scrolls instead of overflowing at minimum height', (
    tester,
  ) async {
    final previousTranslations = Localization.translations;
    Localization.translations =
        Translations.byLocale('en-US') +
        {
          'en-US': {
            'get_unlimited_data': 'Get unlimited data, and faster speeds!',
            'upgrade_to_pro': 'Upgrade to Pro',
            'routing_mode': 'Routing Mode',
            'full_tunnel': 'Full Tunnel',
            'split_tunneling': 'Split Tunneling',
            'disabled': 'Disabled',
            'vpn_status': 'VPN Status',
            'smart_location': 'Smart Location',
            'U.S.A. - Phoenix': 'U.S.A. - Phoenix',
            'daily_data_cap_reached_message':
                'Speed reduced to 128 kb/sec - Resets at %s.',
            'daily_data_usage': 'Daily Data Usage',
            'mb': 'MB',
          },
        };
    addTearDown(() => Localization.translations = previousTranslations);

    // Preserve the production minimum height and vertical ScreenUtil scale.
    // The wider viewport avoids a horizontal overflow caused only by the Ahem
    // test font while exercising the vertical layout from the Windows smoke.
    tester.view.physicalSize = const Size(520, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isUserProProvider.overrideWithValue(false),
          lanternServiceProvider.overrideWithValue(_FakeLanternService()),
          serverLocationProvider.overrideWithValue(
            ServerLocation(
              serverName: '',
              serverType: ServerLocationType.auto.name,
              autoLocation: const AutoLocation(
                country: 'United States',
                countryCode: 'US',
                displayName: 'U.S.A. - Phoenix',
              ),
            ),
          ),
          radianceSettingsProvider.overrideWithValue(
            const RadianceSettingsState(routingMode: RoutingMode.full),
          ),
          vpnProvider.overrideWithValue(VPNStatus.disconnected),
          macosExtensionProvider.overrideWithValue(
            const MacOSExtensionState(SystemExtensionStatus.unknown),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 800),
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: 500, height: 569, child: VpnTab()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('vpn.tab.scroll')), findsOneWidget);
  });
}
