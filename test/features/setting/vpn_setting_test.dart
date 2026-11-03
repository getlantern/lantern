import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide VPNSetting;
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/setting/vpn_setting.dart';

class _Radiance extends RadianceSettings {
  @override
  RadianceSettingsState build() => const RadianceSettingsState();
}

Future<void> _pump(
  WidgetTester tester, {
  required bool servers,
  required bool proxies,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        radianceSettingsProvider.overrideWith(_Radiance.new),
        isUserProProvider.overrideWithValue(true),
        isPrivateServerFoundProvider.overrideWithValue(servers),
        personalProxiesTabVisibleProvider.overrideWithValue(proxies),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const VPNSetting(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const manage = Key('vpn_setting.manage_private_locations');

  testWidgets('Manage Private Locations shows for private servers or '
      'personal proxies', (tester) async {
    await _pump(tester, servers: false, proxies: false);
    expect(find.byKey(manage), findsNothing);
    await _pump(tester, servers: true, proxies: false);
    expect(find.byKey(manage), findsOneWidget);
    await _pump(tester, servers: false, proxies: true);
    expect(find.byKey(manage), findsOneWidget);
  });
}
