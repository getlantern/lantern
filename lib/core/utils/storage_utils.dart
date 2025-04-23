import 'dart:io';

import 'package:lantern/core/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';

class AppStorageUtils {
  static Future<String> getAppLogDirectory() async {
    // Get the platform-specific directory to store logs
    Directory logDir;
    if (Platform.isIOS || Platform.isAndroid) {
      Directory baseDir = await getApplicationDocumentsDirectory();
      final path = baseDir.path;
      if (path.endsWith("/app_flutter")) {
        baseDir = Directory(path.replaceFirst("/app_flutter", ""));
      }
      logDir = Directory("${baseDir.path}/logs");
    } else if (Platform.isMacOS) {
      logDir = await getLibraryDirectory();
      logDir = Directory("${logDir.path}/Logs/Lantern");
    } else if (Platform.isLinux) {
      logDir = await getApplicationSupportDirectory();
      logDir = Directory("${logDir.path}/.lantern/logs");
    } else if (Platform.isWindows) {
      logDir = await getApplicationSupportDirectory();
      logDir = Directory("${logDir.path}/Lantern/logs");
    } else {
      throw UnsupportedError("Unsupported platform for log directory");
    }
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    appLogger.debug("Using log directory $logDir");
    return logDir.path;
  }

  static Future<Directory> getAppDirectory() async {
    final Directory appDir;
    if (Platform.isIOS || Platform.isAndroid) {
      Directory baseDir = await getApplicationDocumentsDirectory();
      final path = baseDir.path;
      if (path.endsWith("/app_flutter")) {
        baseDir = Directory(path.replaceFirst("/app_flutter", ""));
      }
      appDir = Directory("${baseDir.path}/.lantern");
    } else {
      // Note this is the application support directory *with*
      // the fully qualified name of our app.
      appDir = await getApplicationSupportDirectory();
    }

    if (!appDir.existsSync()) {
      appDir.createSync(recursive: true);
    }
    appLogger.debug("Using app directory $appDir");
    return appDir;
  }

  static Future<File> appLogFile() async {
    final logDir = await getAppLogDirectory();
    final logFile = File("$logDir/lantern.log");

    if (!logFile.existsSync()) {
      throw Exception("Log file does not exist.");
    }
    return logFile;
  }
}
