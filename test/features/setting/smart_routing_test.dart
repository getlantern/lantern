import 'dart:async';

import 'package:material_ui/material_ui.dart';
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
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

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

/// The real settings notifier over a service whose routing writes wait on
/// completers the test controls.
class _Service implements LanternService {
  _Service({required this.smart});
  bool smart;
  final writes = <bool>[];
  final gates = <Completer<void>>[];

  @override
  Future<Either<Failure, Unit>> setRoutingMode(bool smart) async {
    writes.add(smart);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    this.smart = smart;
    return right(unit);
  }

  @override
  Future<Either<Failure, bool>> isSmartRoutingEnabled() async => right(smart);
  @override
  Future<Either<Failure, bool>> isBlockAdsEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isTelemetryEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isPeerProxyEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isUnboundedEnabled() async => right(false);
  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async =>
      right(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  testWidgets('tapping back to Full Tunnel while the Smart Routing write '
      'runs reverses it: the last tap wins', (tester) async {
    final service = _Service(smart: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const SmartRouting(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(card, findsNothing, reason: 'starts on Full Tunnel');

    await tester.tap(find.text('smart_routing'.i18n));
    await tester.pump();
    await tester.tap(find.text('full_tunnel'.i18n));
    await tester.pump();
    expect(service.writes, [true], reason: 'the second waits for the first');

    service.gates[0].complete();
    await tester.pumpAndSettle();
    expect(service.writes, [true, false]);
    service.gates[1].complete();
    await tester.pumpAndSettle();
    expect(service.smart, isFalse);
    expect(card, findsNothing, reason: 'Full Tunnel, as last tapped');
    expect(find.byType(SmartRouting), findsOneWidget);
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
