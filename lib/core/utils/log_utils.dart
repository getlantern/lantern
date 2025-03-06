import 'dart:io';
import 'package:lantern/core/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';

Future<String> getAppLogDirectory() async {
  final libraryDir = await getLibraryDirectory();
  final logDir = Directory("${libraryDir.path}/Logs/Lantern");

  // Make sure the directory exists
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  appLogger.debug("Using log directory $logDir");

  return logDir.path;
}
