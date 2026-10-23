import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme;
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/features/split_tunneling/alphabet_index_bar.dart';
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart';
import 'package:lantern/features/split_tunneling/provider/app_icon_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';

import '../../../integration_test/vpn/split_tunneling_smoke_helpers.dart';

class _EnabledApps extends SplitTunnelingApps {
  _EnabledApps(this.apps);

  final Set<AppData> apps;

  @override
  FutureOr<Set<AppData>> build() => apps;

  void setApps(Set<AppData> apps) => state = AsyncData(apps);
}

AppData _app(String name) => AppData(
  name: name,
  bundleId: 'test.$name',
  appPath: '/Applications/$name.app',
  iconPath: '',
);

Future<void> _pumpApps(
  WidgetTester tester, {
  required Size size,
  required List<AppData> apps,
  Set<AppData> enabled = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appsDataProvider.overrideWith((ref) => Stream.value(apps)),
        splitTunnelingAppsProvider.overrideWith(() => _EnabledApps(enabled)),
        appIconBytesProvider.overrideWith((ref, key) => null),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.appTheme(),
          home: const AppsSplitTunneling(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('short viewports do not break index layout', (tester) async {
    await _pumpApps(
      tester,
      size: const Size(800, 160),
      apps: [_app('Alpha'), _app('Zulu')],
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('index stays usable below a long bypass list', (tester) async {
    final enabled = {for (var i = 0; i < 30; i++) _app('Enabled $i')};
    final installed = [
      for (var code = 65; code <= 90; code++)
        _app('${String.fromCharCode(code)} app'),
    ];
    await _pumpApps(
      tester,
      size: const Size(800, 600),
      apps: [...enabled, ...installed],
      enabled: enabled,
    );

    final lastLetter = find.descendant(
      of: find.byType(AlphabetIndexBar),
      matching: find.text('Z'),
    );
    expect(lastLetter.hitTestable(), findsOneWidget);
    await tester.tap(lastLetter);
    await tester.pumpAndSettle();

    expect(find.text('Z app').hitTestable(), findsOneWidget);

    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    final offset = position.pixels;
    await tester.drag(find.text('Z app'), const Offset(0, 250));
    await tester.pumpAndSettle();

    expect(position.pixels, lessThan(offset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('smoke finds an installed app without selecting it', (
    tester,
  ) async {
    final enabled = {for (var i = 0; i < 30; i++) _app('Enabled $i')};
    final game = _app('Registered Game');
    await _pumpApps(
      tester,
      size: const Size(800, 400),
      apps: [
        ...enabled,
        for (var i = 0; i < 60; i++) _app('Installed $i'),
        game,
      ],
      enabled: enabled,
    );

    final row = find.byKey(
      ValueKey('split-tunnel-app:${normalizedAppId(game)}'),
    );
    expect(row, findsNothing);
    await expectInstalledApp(tester, query: game.name, row: row);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppsSplitTunneling)),
    );
    expect(container.read(searchQueryProvider), isEmpty);
    expect(container.read(splitTunnelingAppsProvider).value, enabled);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('smoke rejects a saved app that was not discovered', (
    tester,
  ) async {
    final saved = _app('Manual Game');
    await _pumpApps(
      tester,
      size: const Size(800, 400),
      apps: [_app('Installed Game')],
      enabled: {saved},
    );

    await expectLater(
      () => expectInstalledApp(
        tester,
        query: saved.name,
        row: find.byKey(ValueKey('split-tunnel-app:${normalizedAppId(saved)}')),
      ),
      throwsA(isA<TestFailure>()),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppsSplitTunneling)),
    );
    expect(container.read(searchQueryProvider), isEmpty);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final count in [0, 30]) {
    testWidgets(
      'smoke reveals a saved app above the viewport ($count selected)',
      (tester) async {
        final enabled = {for (var i = 0; i < count; i++) _app('Enabled $i')};
        await _pumpApps(
          tester,
          size: const Size(800, 600),
          apps: [
            ...enabled,
            for (var code = 65; code <= 90; code++)
              _app('${String.fromCharCode(code)} app'),
          ],
          enabled: enabled,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlphabetIndexBar),
            matching: find.text('Z'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Z app').hitTestable(), findsOneWidget);

        final added = _app('Z game');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AppsSplitTunneling)),
        );
        (container.read(splitTunnelingAppsProvider.notifier) as _EnabledApps)
            .setApps({...enabled, added});
        await tester.pumpAndSettle();
        final row = find.byKey(
          ValueKey('split-tunnel-app:${normalizedAppId(added)}'),
        );
        expect(row, findsNothing);

        await revealBypassedApp(tester, row);

        expect(find.text(added.name).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
