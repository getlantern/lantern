import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:loggy/loggy.dart';
import 'package:simple_native_logger/simple_native_logger.dart' hide LogLevel;

final dbLogger = Loggy("DB-Logger");
final appLogger = Loggy("app-Logger");


void initLogger(String path) {
  SimpleNativeLogger.init();
  final logPrinter = PlatformUtils.isDesktop
      ? DebugPrintLoggyPrinter()
      : PrettyDeveloperPrinter();

  Loggy.initLoggy(
    logPrinter: FileLogPrinter(path),
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

class FileLogPrinter extends LoggyPrinter {
  final IOSink _sink;

  FileLogPrinter(String path)
      : _sink = File(path).openWrite(mode: FileMode.append);

  @override
  void onLog(LogRecord record) {
    final logLine = "[${record.time.toIso8601String()}] [${record.level.name}] "
        "[${record.loggerName}] ${record.message}";
    _sink.writeln(logLine);
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
