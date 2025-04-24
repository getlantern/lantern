import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:loggy/loggy.dart';

final dbLogger = Loggy("DB-Logger");
final appLogger = Loggy(
  "app-Logger",
);

void initLogger() {
  final logPrinter =
      Platform.isIOS ? DebugPrintLoggyPrinter() : PrettyDeveloperPrinter();

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
