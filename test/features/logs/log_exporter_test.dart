import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/logs/log_exporter.dart';

void main() {
  test('existingLogFiles skips missing paths', () async {
    final dir = await Directory.systemTemp.createTemp('lantern_logs_test_');
    addTearDown(() => dir.delete(recursive: true));

    final existing = File('${dir.path}/flutter.log');
    await existing.writeAsString('flutter log');

    final files = await existingLogFiles([
      existing.path,
      '${dir.path}/missing.log',
      '',
    ]);

    expect(files.map((file) => file.path), [existing.path]);
  });

  test('writeDiagnosticLogBundle writes each log with headers', () async {
    final dir = await Directory.systemTemp.createTemp('lantern_logs_test_');
    addTearDown(() => dir.delete(recursive: true));

    final flutterLog = File('${dir.path}/flutter.log');
    final lanternLog = File('${dir.path}/lantern.log');
    await flutterLog.writeAsString('flutter line\n');
    await lanternLog.writeAsString('lantern line\n');

    final exported = await writeDiagnosticLogBundle(
      [flutterLog, lanternLog],
      '${dir.path}/exported',
      generatedAt: DateTime.utc(2026, 7, 1, 12),
    );

    expect(exported.path, '${dir.path}/exported.txt');
    final contents = await exported.readAsString();
    expect(contents, contains('Lantern diagnostic logs'));
    expect(contents, contains('Generated: 2026-07-01 12:00:00.000Z'));
    expect(contents, contains('Source files:'));
    expect(contents, contains('===== flutter.log ====='));
    expect(contents, contains('flutter line'));
    expect(contents, contains('===== lantern.log ====='));
    expect(contents, contains('lantern line'));
  });

  test('diagnosticLogExportFileName is safe for Windows paths', () {
    final name = diagnosticLogExportFileName(DateTime.utc(2026, 7, 1, 12));

    expect(name, startsWith('lantern-diagnostic-logs-'));
    expect(name, endsWith('.txt'));
    expect(name, isNot(contains(':')));
  });
}
