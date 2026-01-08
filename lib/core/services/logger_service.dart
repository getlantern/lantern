import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:intl/intl.dart';
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

Future<void> initLogger([String? path]) async {
  LoggyPrinter logPrinter;

  if (path != null) {
    try {
      LogRotation.checkAndRotateIfNeeded(
        path: path,
        maxFileSizeInBytes: 10 * 1024 * 1024,
        maxBackupFiles: 1,
      );
    } catch (e) {
      print("Log rotation check failed: $e");
    }
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

// Utility class for log file rotation management
class LogRotation {
  static void checkAndRotateIfNeeded({
    required String path,
    required int maxFileSizeInBytes,
    int maxBackupFiles = 2,
  }) {
    print("Checking log file size for rotation: $path");
    final file = File(path);

    if (!file.existsSync()) {
      file.createSync(recursive: true);
      return;
    }

    final fileSize = file.lengthSync();
    if (fileSize > maxFileSizeInBytes) {
      _rotateLog(file, maxBackupFiles);
    }
  }

  static void _rotateLog(File currentFile, int maxBackupFiles) {
    try {
      print("Rotating log file: ${currentFile.path}");
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final directory = currentFile.parent;
      final fileName = currentFile.path.split(Platform.pathSeparator).last;
      final nameWithoutExt = fileName.replaceAll('.log', '');

      // Create backup file path
      final backupPath =
          '${directory.path}${Platform.pathSeparator}${nameWithoutExt}_$timestamp.log';
      currentFile.renameSync(backupPath);

      // Compress the backup file to zip
      final zipPath =
          '${directory.path}${Platform.pathSeparator}${nameWithoutExt}_$timestamp.zip';
      _compressFile(backupPath, zipPath);
      // Delete the original log file after compression
      File(backupPath).deleteSync();
      // Create new log file
      File(currentFile.path).createSync();
      // Clean up old backups (now looking for .zip files)
      _cleanupOldBackups(
          directory, nameWithoutExt, currentFile.path, maxBackupFiles);

      debugPrint("Log rotated and compressed: $zipPath");
    } catch (e, st) {
      debugPrint("Failed to rotate log: $e\n$st");
    }
  }

  static void _compressFile(String sourcePath, String zipPath) {
    try {
      final sourceFile = File(sourcePath);
      final bytes = sourceFile.readAsBytesSync();

      // Create archive
      final archive = Archive();
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));

      // Encode to zip
      final zipData = ZipEncoder().encode(archive);

      // Write zip file
      if (zipData != null) {
        File(zipPath).writeAsBytesSync(zipData);
      }
    } catch (e, st) {
      debugPrint("Failed to compress log file: $e\n$st");
    }
  }

  static void _cleanupOldBackups(
    Directory directory,
    String nameWithoutExt,
    String currentPath,
    int maxBackupFiles,
  ) {
    try {
      final files = directory.listSync();
      final backupFiles = files.whereType<File>().where((f) {
        final name = f.path.split(Platform.pathSeparator).last;
        return name.startsWith(nameWithoutExt) &&
            name.endsWith('.zip'); // Look for .zip files
      }).toList();

      backupFiles
          .sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      if (backupFiles.length > maxBackupFiles) {
        final filesToDelete =
            backupFiles.take(backupFiles.length - maxBackupFiles);
        for (var file in filesToDelete) {
          file.deleteSync();
          debugPrint("Deleted old log backup: ${file.path}");
        }
      }
    } catch (e, st) {
      debugPrint("Failed to cleanup old backups: $e\n$st");
    }
  }
}
