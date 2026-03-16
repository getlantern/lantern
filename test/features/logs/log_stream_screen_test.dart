import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/logs/logs.dart';
import 'package:lantern/features/logs/provider/diagnostic_log_notifier.dart';

class _FakeDiagnosticLogNotifier extends DiagnosticLogNotifier {
  final Stream<List<String>> _stream;

  _FakeDiagnosticLogNotifier(this._stream);

  @override
  Stream<List<String>> build() => _stream;

  @override
  Future<List<String>> diagnosticLogFilePath() async => const [];
}

void main() {
  testWidgets('diagnostic logs screen renders streaming updates',
      (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticLogProvider.overrideWith(
            () => _FakeDiagnosticLogNotifier(controller.stream),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: const MaterialApp(
            home: Logs(),
          ),
        ),
      ),
    );

    await tester.pump();

    controller.add(const <String>[
      'INFO[first] first log line',
    ]);
    await tester.pumpAndSettle();

    expect(find.textContaining('first log line'), findsOneWidget);

    controller.add(const <String>[
      'INFO[first] first log line',
      'ERROR[second] second log line',
    ]);
    await tester.pumpAndSettle();

    expect(find.textContaining('second log line'), findsOneWidget);
  });
}
