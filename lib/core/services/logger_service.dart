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

class FileLogPrinter extends LoggyPrinter {
  final IOSink _sink;

  FileLogPrinter(String path)
      : _sink = File(path).openWrite(mode: FileMode.append);

  @override
  void onLog(LogRecord record) {
    final logLine = "[${record.time.toIso8601String()}] [${record.level.name}] "
        "[${record.loggerName}] ${record.message}";
    _sink.writeln(logLine);

    if (record.error != null) {
      _sink.writeln("Error: ${record.error}");
    }
    if (record.stackTrace != null) {
      _sink.writeln("Stack: ${record.stackTrace}");
    }
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
