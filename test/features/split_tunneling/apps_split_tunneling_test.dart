import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme;
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';
import 'package:lantern/features/split_tunneling/alphabet_index_bar.dart';
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart';
import 'package:lantern/features/split_tunneling/provider/app_icon_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';

class _Snapshot extends SplitTunnel {
  @override
  Future<SplitTunnelState> build() async => const SplitTunnelState(
    enabled: true,
    policy: SplitTunnelPolicy.bypass,
    supported: true,
  );
}

class _EnabledApps extends SplitTunnelingApps {
  _EnabledApps(this.apps);

  final Set<AppData> apps;
  int clearCalls = 0;

  @override
  Future<Failure?> deselectAllApps() async {
    clearCalls++;
    state = const AsyncData({});
    return null;
  }

  @override
  FutureOr<Set<AppData>> build() => apps;
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
  _EnabledApps? notifier,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        splitTunnelProvider.overrideWith(_Snapshot.new),
        appsDataProvider.overrideWith((ref) => Stream.value(apps)),
        splitTunnelingAppsProvider.overrideWith(
          () => notifier ?? _EnabledApps(enabled),
        ),
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
  testWidgets(
    'Clear remains available when search hides all stored selections',
    (tester) async {
      final apps = _EnabledApps({_app('Removed'), _app('Hidden')});
      await _pumpApps(
        tester,
        size: const Size(800, 600),
        apps: [],
        notifier: apps,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppsSplitTunneling)),
      );
      container.read(searchQueryProvider.notifier).setQuery('nothing matches');
      await tester.pumpAndSettle();
      expect(find.text('Removed'), findsNothing);
      await tester.tap(find.byKey(const Key('split_tunneling.apps.clear')));
      await tester.pumpAndSettle();
      expect(apps.clearCalls, 1);
      expect(container.read(splitTunnelingAppsProvider).requireValue, isEmpty);
    },
  );

  testWidgets(
    'Windows executable action is absent on other platforms',
    (tester) async {
      await _pumpApps(tester, size: const Size(800, 600), apps: []);
      expect(
        find.byKey(const ValueKey('add-windows-executable')),
        findsNothing,
      );
    },
    skip: Platform.isWindows,
  );

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
}
