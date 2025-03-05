import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> getAppLogDirectory() async {
  final libraryDir = await getLibraryDirectory();
  final logDir = Directory("${libraryDir.path}/Logs/Lantern");

  // Ensure the directory exists
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  print("Using log directory $logDir");

  return logDir.path;
}
