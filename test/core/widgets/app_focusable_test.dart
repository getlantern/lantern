import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/desktop/app_shortcuts.dart';
import 'package:lantern/core/widgets/app_focusable.dart';

/// Counts how often it is mounted, to catch focus changes remounting the child.
class _Mounts extends StatefulWidget {
  const _Mounts();

  static int count = 0;

  @override
  State<_Mounts> createState() => _MountsState();
}

class _MountsState extends State<_Mounts> {
  @override
  void initState() {
    super.initState();
    _Mounts.count++;
  }

  @override
  Widget build(BuildContext context) => const Text('card');
}

void main() {
  BoxDecoration? ring(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.ancestor(
                  of: find.text('card'),
                  matching: find.byType(Container),
                ),
              )
              .foregroundDecoration
          as BoxDecoration?;

  testWidgets('D-pad select activates and shows a ring without resizing', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFocusable(
            onActivate: () => activations++,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(width: 100, height: 40, child: Text('card')),
          ),
        ),
      ),
    );
    final sizeBefore = tester.getSize(find.byType(AppFocusable));
    expect(ring(tester)?.border, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(tester)?.border, isNotNull, reason: 'focus ring shows');
    expect(tester.getSize(find.byType(AppFocusable)), sizeBefore);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(activations, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 2, reason: 'Enter activates too');
  });

  testWidgets('focus changes do not remount the child', (tester) async {
    _Mounts.count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFocusable(onActivate: () {}, child: const _Mounts()),
        ),
      ),
    );
    expect(_Mounts.count, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(tester)?.border, isNotNull, reason: 'focused');
    expect(_Mounts.count, 1, reason: 'child kept its state');
  });

  testWidgets('Enter on a focused target wins over a form Enter shortcut', (
    tester,
  ) async {
    var activations = 0;
    var submits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnterKeyShortcut(
            onEnter: () => submits++,
            child: AppFocusable(
              onActivate: () => activations++,
              child: const Text('card'),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 1);
    expect(submits, 0, reason: 'the form did not submit');
  });

  testWidgets('tap activates unless the child handles taps itself', (
    tester,
  ) async {
    var activations = 0;
    for (final handlesTap in [true, false]) {
      activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFocusable(
              onActivate: () => activations++,
              handlesTap: handlesTap,
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AppFocusable));
      await tester.pump();
      expect(activations, handlesTap ? 1 : 0, reason: 'handlesTap=$handlesTap');
    }
  });

  testWidgets('a disabled target is skipped by focus', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppFocusable(onActivate: null, child: Text('card')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(tester)?.border, isNull);
  });
}
