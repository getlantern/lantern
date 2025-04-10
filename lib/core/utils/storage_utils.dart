import 'dart:io';
import 'package:lantern/core/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';

class AppStorageUtils {
  static Future<String> getAppLogDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final logDir = Directory("${baseDir.path}/Logs");

    // Make sure the directory exists
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }

    appLogger.debug("Using log directory $logDir");

    return logDir.path;
  }

  static Future<File> appLogFile() async {
    final logDir = await getAppLogDirectory();
    final logFile = File("$logDir/lantern.log");

    if (!logFile.existsSync()) {
      throw Exception("Log file does not exist.");
    }
    return logFile;
  }

  static Future<String> getAppDataDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final dataDir = Directory("${baseDir.path}/Data");

    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    appLogger.debug("Using app data directory $dataDir");

    return dataDir.path;
  }
}
