import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:loggy/loggy.dart';

/// An unrotated log grows without bound — one report arrived with a 297 MB
/// flutter.log — and that is what pushes an issue report past its attachment
/// budget, so the user cannot send logs at all.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lantern-log-rotation-test');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });

  LogRecord record(String message) => LogRecord(
    LogLevel.info,
    message,
    'test-logger',
    DateTime.utc(2026, 8, 25, 19, 30),
  );

  /// Writes [count] lines and then drains the printer.
  ///
  /// Closing is the deterministic sync point: writes and rotations run in a
  /// StreamController + asyncMap doing real file I/O, so sleeping a fixed
  /// number of times races the pipeline and fails under load — asserting
  /// mid-rotation once showed 3 backups where pruning had not yet run.
  Future<void> writeLinesAndDrain(
    FileLogPrinter printer,
    int count,
    int width,
  ) async {
    final payload = 'x' * width;
    for (var i = 0; i < count; i++) {
      printer.onLog(record('$i $payload'));
    }
    await printer.close();
  }

  List<File> backups(Directory d) => d
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.log.gz'))
      .toList();

  test('keeps the live log under the size limit', () async {
    final path = '${dir.path}/flutter.log';
    final printer = FileLogPrinter(
      path,
      maxFileBytes: 16 * 1024,
      maxBackups: 2,
      checkInterval: 2 * 1024,
    );

    await writeLinesAndDrain(printer, 400, 512);

    final live = File(path);
    expect(live.existsSync(), isTrue);
    expect(
      await live.length(),
      lessThan(64 * 1024),
      reason:
          'the live log must be bounded; without rotation these writes '
          'accumulate to well over 200 KB and keep going',
    );
  });

  test('writes compressed backups the report archiver can find', () async {
    final path = '${dir.path}/flutter.log';
    final printer = FileLogPrinter(
      path,
      maxFileBytes: 16 * 1024,
      maxBackups: 2,
      checkInterval: 2 * 1024,
    );

    await writeLinesAndDrain(printer, 400, 512);

    final found = backups(dir);
    expect(found, isNotEmpty, reason: 'rotation should leave a backup behind');
    // radiance's issue archiver globs "<name>-*.log.gz" and parses the
    // timestamp as 2006-01-02T15-04-05.000, so the shape has to match or the
    // backups silently never reach a report.
    for (final f in found) {
      expect(
        f.uri.pathSegments.last,
        matches(
          RegExp(
            r'^flutter-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}\.log\.gz$',
          ),
        ),
      );
    }
    // Real gzip, not a renamed plain file.
    expect(gzip.decode(found.first.readAsBytesSync()), isNotEmpty);
  });

  test('prunes old backups', () async {
    final path = '${dir.path}/flutter.log';
    final printer = FileLogPrinter(
      path,
      maxFileBytes: 8 * 1024,
      maxBackups: 2,
      checkInterval: 1024,
    );

    // Enough to force several rotations.
    await writeLinesAndDrain(printer, 1200, 512);

    final found = backups(dir);
    expect(
      found,
      isNotEmpty,
      reason: 'without at least one backup this assertion is vacuous',
    );
    expect(
      found.length,
      lessThanOrEqualTo(2),
      reason: 'backups must be pruned, or rotation just moves the growth',
    );
  });
}
