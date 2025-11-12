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
      ..write("[${record.time.toIso8601String()}] ")
      ..write("[${record.level.name}] ")
      ..write("[${record.loggerName}] ")
      ..writeln(record.message);

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

  Future<void> close() async {
    await _controller.close();
  }
}
