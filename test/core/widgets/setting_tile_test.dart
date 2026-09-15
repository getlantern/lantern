import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/widgets/setting_tile.dart';

void main() {
  for (final labels in [
    (
      language: 'English',
      routing: 'Routing Mode',
      mode: 'Smart Routing',
      split: 'Split Tunneling',
      status: 'Disabled',
    ),
    (
      language: 'French',
      routing: 'Mode de routage',
      mode: 'Routage intelligent',
      split: 'Tunneling fractionné',
      status: 'Désactivé',
    ),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'compact settings wrap ${labels.language} text at scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 568);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          var routingTaps = 0;
          var splitTaps = 0;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.appTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: Row(
                      children: [
                        Expanded(
                          child: SettingTile(
                            label: labels.routing,
                            value: labels.mode,
                            icon: const Icon(Icons.route),
                            actions: const [],
                            onTap: () => routingTaps++,
                          ),
                        ),
                        const SizedBox(width: 1),
                        Expanded(
                          child: SettingTile(
                            label: labels.split,
                            value: labels.status,
                            icon: const Icon(Icons.call_split),
                            actions: const [],
                            onTap: () => splitTaps++,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          for (final text in [
            labels.routing,
            labels.mode,
            labels.split,
            labels.status,
          ]) {
            final finder = find.descendant(
              of: find.byType(SettingTile),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is RichText && widget.text.toPlainText() == text,
              ),
            );
            expect(finder, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(paragraph.didExceedMaxLines, isFalse, reason: text);
          }
          await tester.ensureVisible(find.text(labels.routing));
          await tester.tap(find.text(labels.routing));
          await tester.ensureVisible(find.text(labels.split));
          await tester.tap(find.text(labels.split));
          expect(routingTaps, 1);
          expect(splitTaps, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
