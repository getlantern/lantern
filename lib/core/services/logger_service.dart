import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:loggy/loggy.dart';

final dbLogger = Loggy("DB-Logger");
final appLogger = Loggy("app-Logger");

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
        '[${record.level.name}] ${record.loggerName}: ${record.message}');
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

/// A printer that writes logs to a file
class FileLogPrinter extends LoggyPrinter {
  final IOSink _sink;
  final StreamController<String> _controller;

  FileLogPrinter(String path)
      : _sink = File(path).openWrite(mode: FileMode.append),
        _controller = StreamController<String>() {
    _controller.stream.asyncMap(
      (event) async {
        _sink.write(event);
        await _sink.flush();
      },
    ).listen((_) {}, onError: (e, st) {
      // If writing to the file fails, print to console as a fallback.
      debugPrint("Failed to write log to file: $e\n$st");
    });
  }

  @override
  void onLog(LogRecord record) {
    final buffer = StringBuffer()
      ..write('time="${_formatTimestamp(record.time)}" ')
      ..write("level=${record.level.name} ")
      ..write("logger=${record.loggerName} ")
      ..write("message=${record.message}");

    if (record.error != null) buffer.writeln("Error: ${record.error}");
    if (record.stackTrace != null) {
      buffer.writeln("Stack: ${record.stackTrace}");
    }

    try {
      _controller.add(buffer.toString());
    } catch (_) {
      // If add throws (controller closed between check and add), ignore silently.
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
