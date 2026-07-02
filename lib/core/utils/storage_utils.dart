import 'dart:io';

import 'package:lantern/core/services/logger_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppStorageUtils {
  /// Base directory for Lantern's shared data on Windows.
  static String get _windowsPublicDir =>
      Platform.environment['PUBLIC'] ?? r'C:\Users\Public';

  static Future<String> getAppLogDirectory() async {
    // Get the platform-specific directory to store logs
    Directory logDir;
    if (Platform.isIOS || Platform.isAndroid) {
      Directory baseDir = await getApplicationDocumentsDirectory();
      final path = baseDir.path;
      if (path.endsWith("/app_flutter")) {
        baseDir = Directory(path.replaceFirst("/app_flutter", ""));
      }
      logDir = Directory("${baseDir.path}/.lantern/logs");
    } else if (Platform.isMacOS) {
      logDir = Directory('/Users/Shared/Lantern/Logs');
    } else if (Platform.isLinux) {
      final baseDir = await getApplicationSupportDirectory();
      logDir = Directory("${baseDir.path}/logs");
    } else if (Platform.isWindows) {
      // Use p.join so the path uses native separators. Mixing '/' into a
      // Windows path breaks StorageFile.GetFileFromPathAsync, which share_plus
      // relies on to attach files to the Windows share sheet.
      logDir = Directory(p.join(_windowsPublicDir, 'Lantern', 'logs'));
    } else {
      throw UnsupportedError("Unsupported platform for log directory");
    }
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
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
    } else if (Platform.isMacOS) {
      appDir = Directory('/Users/Shared/Lantern');
    } else if (Platform.isWindows) {
      appDir = Directory(p.join(_windowsPublicDir, 'Lantern', 'data'));
    } else {
      // Note this is the application support directory *with*
      // the fully qualified name of our app.
      appDir = await getApplicationSupportDirectory();
    }

    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    appLogger.debug("Using app directory $appDir");
    return appDir;
  }

  static Future<File> appLogFile({bool createIfMissing = true}) async {
    final logDir = await getAppLogDirectory();
    final logFile = File(p.join(logDir, "lantern.log"));

    if (createIfMissing && !await logFile.exists()) {
      await logFile.create(recursive: true);
    }
    return logFile;
  }

  static Future<File> flutterLogFile() async {
    final dir = await getAppLogDirectory();
    final logFile = File(p.join(dir, "flutter.log"));
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }
    appLogger.debug("Using flutter log file at: ${logFile.path}");
    return logFile;
  }

  static Future<List<String>> logsFilePaths() async {
    final logDirPath = await getAppLogDirectory();
    final logDir = Directory(logDirPath);
    if (!await logDir.exists()) return const [];
    return logDir
        .listSync(recursive: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        // Normalize to native separators; share_plus on Windows can't resolve
        // paths that contain forward slashes.
        .map((f) => p.normalize(f.path))
        .toList(growable: false);
  }
}
