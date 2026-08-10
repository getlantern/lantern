import 'package:flutter_test/flutter_test.dart';

class WidgetWaitUtils {
  const WidgetWaitUtils._();

  static Future<void> waitForFinder(
    WidgetTester tester,
    Finder finder, {
    required Duration timeout,
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    fail(reason ?? 'Timed out waiting for expected widget');
  }

  static Future<void> waitForAnyFinder(
    WidgetTester tester,
    List<Finder> finders, {
    required Duration timeout,
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      for (final finder in finders) {
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
    }
    fail(reason ?? 'Timed out waiting for any expected widget');
  }

  static Future<void> waitForFinderToDisappear(
    WidgetTester tester,
    Finder finder, {
    required Duration timeout,
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isEmpty) {
        return;
      }
    }
    fail(reason ?? 'Timed out waiting for widget to disappear');
  }
}
