import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide SmartRouting;
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/setting/smart_routing.dart';

class _Radiance extends RadianceSettings {
  _Radiance(this.mode);
  final RoutingMode mode;
  final writes = <bool>[];

  @override
  RadianceSettingsState build() => RadianceSettingsState(routingMode: mode);

  final modes = <RoutingMode>[];

  @override
  Future<Either<Failure, Unit>> setRoutingMode(RoutingMode mode) async {
    modes.add(mode);
    state = state.copyWith(routingMode: mode);
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setProxyless(bool value) async {
    writes.add(value);
    state = state.copyWith(proxyless: value);
    return right(unit);
  }
}

Future<_Radiance> _pump(WidgetTester tester, RoutingMode mode) async {
  final radiance = _Radiance(mode);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [radianceSettingsProvider.overrideWith(() => radiance)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const SmartRouting(),
        ),
      ),
    ),
  );
  await tester.pump();
  return radiance;
}

void main() {
  setUpAll(Localization.loadTranslations);

  final options = find.byKey(const Key('smart_routing.options'));
  final card = find.byKey(const Key('smart_routing.proxyless_card'));
  final toggle = find.byKey(const Key('smart_routing.proxyless'));
  final note = find.byKey(const Key('smart_routing.note'));

  testWidgets('Smart Routing: the two radios, then Smart Routing options, '
      'the Try Direct First card with its switch on, and one note', (
    tester,
  ) async {
    await _pump(tester, RoutingMode.smart);
    expect(find.text('smart_routing'.i18n), findsOneWidget);
    expect(find.text('full_tunnel'.i18n), findsOneWidget);
    expect(options, findsOneWidget);
    expect(find.text('smart_routing_options'.i18n), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('proxyless'.i18n)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('proxyless_reaches_blocked'.i18n),
      ),
      findsOneWidget,
    );
    expect(tester.widget<SwitchButton>(toggle).value, isTrue);
    expect(find.byType(InfoRow), findsOneWidget);
    expect(
      find.descendant(
        of: note,
        matching: find.text('smart_routing_direct_description'.i18n),
      ),
      findsOneWidget,
    );
    // Top to bottom: radios, label, card, note.
    final radios = find.byType(AppCard).first;
    expect(
      tester.getBottomLeft(radios).dy,
      lessThan(tester.getTopLeft(options).dy),
    );
    expect(
      tester.getBottomLeft(options).dy,
      lessThan(tester.getTopLeft(card).dy),
    );
    expect(tester.getBottomLeft(card).dy, lessThan(tester.getTopLeft(note).dy));
  });

  testWidgets('the switch writes Try Direct First', (tester) async {
    final radiance = await _pump(tester, RoutingMode.smart);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(radiance.writes, [false]);
    expect(tester.widget<SwitchButton>(toggle).value, isFalse);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(radiance.writes, [false, true]);
  });

  testWidgets('picking a mode keeps the screen open and shows or hides '
      "Smart Routing's options", (tester) async {
    final radiance = await _pump(tester, RoutingMode.smart);
    expect(card, findsOneWidget);
    await tester.tap(find.text('full_tunnel'.i18n));
    await tester.pumpAndSettle();
    expect(radiance.modes, [RoutingMode.full]);
    expect(find.byType(SmartRouting), findsOneWidget);
    expect(options, findsNothing);
    expect(card, findsNothing);
    expect(note, findsNothing);
    await tester.tap(find.text('smart_routing'.i18n));
    await tester.pumpAndSettle();
    expect(radiance.modes, [RoutingMode.full, RoutingMode.smart]);
    expect(find.byType(SmartRouting), findsOneWidget);
    expect(card, findsOneWidget);
    // The mode already selected is not written again.
    await tester.tap(find.text('smart_routing'.i18n));
    await tester.pumpAndSettle();
    expect(radiance.modes, [RoutingMode.full, RoutingMode.smart]);
  });

  testWidgets('Full Tunnel: only the two radios', (tester) async {
    await _pump(tester, RoutingMode.full);
    expect(find.text('smart_routing'.i18n), findsOneWidget);
    expect(find.text('full_tunnel'.i18n), findsOneWidget);
    expect(options, findsNothing);
    expect(card, findsNothing);
    expect(note, findsNothing);
    expect(find.byType(InfoRow), findsNothing);
  });
}
