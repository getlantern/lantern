import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:lantern/core/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';

class AppStorageUtils {
  static Future<String> getAppLogDirectory() async {
    final Directory baseDir;

    if (Platform.isIOS || Platform.isAndroid) {
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isMacOS) {
      baseDir = await getLibraryDirectory();
    } else if (Platform.isLinux || Platform.isWindows) {
      baseDir = await getApplicationSupportDirectory();
    } else {
      throw UnsupportedError("Unsupported platform for log directory");
    }

    // Construct platform-appropriate log path
    final logPath = Platform.isMacOS
        ? p.join(baseDir.path, 'Logs', 'Lantern')
        : Platform.isWindows
            ? p.join(baseDir.path, 'Lantern', 'logs')
            : p.join(baseDir.path, 'logs');

    final Directory logDir = Directory(logPath);

    if (!await logDir.exists()) {
      try {
        await logDir.create(recursive: true);
        appLogger.debug("Created log directory at: $logPath");
      } catch (e) {
        appLogger.error("Failed to create log directory: $e");
        rethrow;
      }
    } else {
      appLogger.debug("Using existing log directory: $logPath");
    }

    return logDir.path;
  }

  static Future<Directory> getAppDirectory() async {
    final Directory baseDir;

    if (Platform.isIOS || Platform.isAndroid) {
      baseDir = await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationSupportDirectory();
    }

    String path;

    if (Platform.isIOS || Platform.isAndroid) {
      path = baseDir.path.endsWith("/app_flutter")
          ? baseDir.path.replaceFirst("/app_flutter", "/.lantern")
          : p.join(baseDir.path, ".lantern");
    } else {
      path = p.join(baseDir.path, "Lantern");
    }

    final appDir = Directory(path);

    if (!await appDir.exists()) {
      try {
        await appDir.create(recursive: true);
        appLogger.debug("Created app directory at: $path");
      } catch (e) {
        appLogger.error("Failed to create app directory: $e");
        rethrow;
      }
    } else {
      appLogger.debug("Using existing app directory: $path");
    }

    return appDir;
  }

  static Future<File> appLogFile() async {
    final logDirPath = await getAppLogDirectory();
    final logFile = File(p.join(logDirPath, 'lantern.log'));
    return logFile;
  }
}
