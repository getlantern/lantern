import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/share_my_connection/action_mode_widgets.dart';

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('desktop pills fill the strip height with inset sides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionModeNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
            vpnActive: false,
            actionActive: false,
            desktop: true,
          ),
        ),
      ),
    );
    final nav = find.byType(ActionModeNavigation);
    final pill = find.byKey(const Key('action-mode.nav.0'));
    expect(tester.getSize(nav).height, 56);
    expect(tester.getSize(pill).height, 40);
    expect(tester.getSize(pill).width, 140.5);
    final strip = tester.widget<Container>(
      find.descendant(of: nav, matching: find.byType(Container)).first,
    );
    expect((strip.decoration! as BoxDecoration).border, isNull);
    expect(tester.takeException(), isNull);
  });

  // Ahem renders each character 14 px wide: Action Mode needs 154 px at 1×,
  // plus 56 px for the icon, gaps, dot, and inner padding.
  for (final (width, scale, truncated) in [
    (393.0, 1.0, true),
    (460.0, 1.0, false),
    (780.0, 2.0, false),
  ]) {
    testWidgets(
      'desktop label fits available space at width $width and scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.windows,
              textTheme: const TextTheme(labelLarge: TextStyle(fontSize: 14)),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: ActionModeNavigation(
                selectedIndex: 1,
                onSelected: (_) {},
                vpnActive: false,
                actionActive: true,
                desktop: true,
              ),
            ),
          ),
        );
        final label = find.descendant(
          of: find.text('unbounded'.i18n),
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, truncated);
        expect(tester.getSize(find.byType(ActionModeNavigation)).width, width);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final desktop in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets('navigation uses themed states: $desktop, $brightness', (
        tester,
      ) async {
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => ActionModeNavigation(
                  selectedIndex: selected,
                  onSelected: (index) => setState(() => selected = index),
                  vpnActive: false,
                  actionActive: true,
                  desktop: desktop,
                ),
              ),
            ),
          ),
        );
        final navigation = find.byType(ActionModeNavigation);
        final context = tester.element(navigation);
        AppImage imageFor(String path) => tester.widget<AppImage>(
          find.byWidgetPredicate((w) => w is AppImage && w.path == path),
        );
        expect(
          imageFor(AppImagePaths.handshake).color,
          context.actionTabbarDisabledText,
        );
        expect(
          imageFor(AppImagePaths.vpnKeyFill).color,
          context.actionTabbarSelectedText,
        );
        await tester.tap(find.byKey(const Key('action-mode.nav.1')));
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(
          imageFor(AppImagePaths.handshakeFill).color,
          context.actionTabbarSelectedText,
        );
        expect(
          imageFor(AppImagePaths.vpnKey).color,
          context.actionTabbarDisabledText,
        );
        final pill = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(const Key('action-mode.nav.1')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(pill.color, context.actionTabbarBg);
        expect(
          (pill.shape! as RoundedRectangleBorder).side.color,
          context.actionTabbarBorder,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
