import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:loggy/loggy.dart';

final dbLogger = Loggy("DB-Logger");
final appLogger = Loggy("app-Logger");

final StreamController<String> _flutterLogController =
    StreamController<String>.broadcast();

/// Emits every log line written to flutter.log as it is written.
Stream<String> get flutterLogLinesStream => _flutterLogController.stream;

/// Pick the right console printer per platform
LoggyPrinter _defaultConsolePrinter() {
  if (PlatformUtils.isDesktop) {
    return DebugPrintLoggyPrinter();
  } else {
    return PrettyDeveloperPrinter();
  }
}

void initLogger([String? path]) {
  LoggyPrinter logPrinter;
  if (path != null) {
    logPrinter = MultiLogPrinter([
      _defaultConsolePrinter(),
      FileLogPrinter(path),
    ]);
  } else {
    logPrinter = _defaultConsolePrinter();
  }

  Loggy.initLoggy(
    logPrinter: logPrinter,
    logOptions: const LogOptions(LogLevel.all),
    hierarchicalLogging: true,
  );
  appLogger.debug("Logger initialized ✅");
}

class DebugPrintLoggyPrinter extends LoggyPrinter {
  const DebugPrintLoggyPrinter();

  @override
  void onLog(LogRecord record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.stackTrace != null) {
      debugPrint('StackTrace:\n${record.stackTrace}');
    }
    if (record.error != null) {
      debugPrint('Error:\n${record.error}');
    }
  }
}

/// A printer that forwards logs to multiple printers
class MultiLogPrinter extends LoggyPrinter {
  final List<LoggyPrinter> _printers;

  MultiLogPrinter(this._printers);

  @override
  void onLog(LogRecord record) {
    for (final printer in _printers) {
      printer.onLog(record);
    }
  }
}

/// A printer that writes logs to a file, rotating it so it stays bounded.
///
/// Without rotation this file grows for the lifetime of the install — one
/// report arrived with a 297 MB flutter.log spanning three months. That is not
/// just wasted disk: an issue report has a hard attachment budget, so an
/// unbounded log is the thing that stops a user from sending us their logs at
/// all.
///
/// Backups are written as `<name>-<timestamp>.log.gz`, the same shape the Go
/// logger produces, so radiance's report archiver picks them up with no
/// changes (see radiance issue/archive.go, backupExt/backupTimeFormat).
class FileLogPrinter extends LoggyPrinter {
  /// Rotate once the live file passes this. Small enough that a whole backup
  /// fits comfortably inside a report's attachment budget.
  static const int defaultMaxFileBytes = 8 * 1024 * 1024;

  /// Compressed backups kept alongside the live file, oldest pruned first.
  static const int defaultMaxBackups = 2;

  /// How much to append between size checks. Checking every line would stat
  /// the file on every log call; this bounds the overshoot instead.
  static const int defaultCheckInterval = 256 * 1024;

  final int _maxFileBytes;
  final int _maxBackups;
  final int _checkInterval;
  final String _path;
  final StreamController<String> _controller;
  IOSink _sink;

  /// Bytes appended since the last size check. Counted in UTF-16 code units,
  /// which undercounts multi-byte text, so it only ever triggers an early
  /// check — the decision itself is made against the real file length.
  int _sinceCheck = 0;

  FileLogPrinter(
    String path, {
    @visibleForTesting int maxFileBytes = defaultMaxFileBytes,
    @visibleForTesting int maxBackups = defaultMaxBackups,
    @visibleForTesting int checkInterval = defaultCheckInterval,
  }) : _path = path,
       _maxFileBytes = maxFileBytes,
       _maxBackups = maxBackups,
       _checkInterval = checkInterval,
       _sink = File(path).openWrite(mode: FileMode.append),
       _controller = StreamController<String>() {
    _controller.stream
        .asyncMap((event) async {
          _sink.write(event);
          await _sink.flush();
          _sinceCheck += event.length;
          if (_sinceCheck >= _checkInterval) {
            _sinceCheck = 0;
            await _rotateIfNeeded();
          }
        })
        .listen(
          (_) {},
          onError: (e, st) {
            // If writing to the file fails, print to console as a fallback.
            debugPrint("Failed to write log to file: $e\n$st");
          },
        );
  }

  Future<void> _rotateIfNeeded() async {
    try {
      final live = File(_path);
      if (!live.existsSync() || await live.length() < _maxFileBytes) return;

      await _sink.flush();
      await _sink.close();
      try {
        await _compressToBackup(live);
      } finally {
        // Reopen even if compressing threw, or logging stops for good. Write
        // mode (not append) truncates, so a failed backup still bounds the
        // file rather than letting it grow unchecked.
        _sink = File(_path).openWrite(mode: FileMode.write);
      }
      await _pruneBackups();
    } catch (e, st) {
      debugPrint("Failed to rotate log file: $e\n$st");
    }
  }

  /// Streams the live file into `<name>-<timestamp>.log.gz`. Streamed rather
  /// than read whole so rotation does not hold the entire file in memory.
  Future<void> _compressToBackup(File live) async {
    final backup = File(
      p.join(p.dirname(_path), '${_logName()}-${_backupStamp()}$_backupExt'),
    );
    await live.openRead().transform(gzip.encoder).pipe(backup.openWrite());
  }

  Future<void> _pruneBackups() async {
    final dir = Directory(p.dirname(_path));
    if (!dir.existsSync()) return;
    final prefix = '${_logName()}-';
    final backups =
        dir.listSync().whereType<File>().where((f) {
            final name = p.basename(f.path);
            return name.startsWith(prefix) && name.endsWith(_backupExt);
          }).toList()
          // Timestamps are fixed-width and zero-padded, so lexical order is
          // chronological.
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final stale in backups.take(
      backups.length - _maxBackups < 0 ? 0 : backups.length - _maxBackups,
    )) {
      try {
        await stale.delete();
      } catch (_) {
        // A backup we cannot delete is not worth failing rotation over.
      }
    }
  }

  String _logName() => p.basenameWithoutExtension(_path);

  /// Matches the Go logger's backup timestamp: 2026-08-25T19-30-00.000
  String _backupStamp() {
    final t = DateTime.now().toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}-${two(t.minute)}-${two(t.second)}'
        '.${t.millisecond.toString().padLeft(3, '0')}';
  }

  static const String _backupExt = '.log.gz';

  @override
  void onLog(LogRecord record) {
    final buffer = StringBuffer()
      ..write('time="${_formatTimestamp(record.time)}" ')
      ..write("level=${record.level.name} ")
      ..write("logger=${record.loggerName} ")
      ..write("message=${record.message}");

    if (record.error != null) buffer.writeln("Error: ${record.error}");
    if (record.stackTrace != null) {
      buffer.write("Stack: ${record.stackTrace}");
    }

    final line = buffer.toString();
    try {
      _controller.add('$line\n');
    } catch (_) {
      // If add throws (controller closed between check and add), ignore silently.
    }
    if (!_flutterLogController.isClosed) {
      _flutterLogController.add(line);
    }
  }

  /// Formats timestamp as: 2026-01-20 16:03:50.628 UTC
  /// Same as radiance logs
  String _formatTimestamp(DateTime timestamp) {
    final utc = timestamp.toUtc();

    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');

    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    final millisecond = utc.millisecond.toString().padLeft(3, '0');

    return '$year-$month-$day $hour:$minute:$second.$millisecond UTC';
  }

  Future<void> close() async {
    await _controller.close();
  }
}
