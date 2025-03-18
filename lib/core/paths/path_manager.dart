import 'dart:io';
import 'package:path/path.dart' as p;

class PathManager {
  final String logsPath;
  final String dbPath;
  final String tempPath;

  PathManager({
    required this.logsPath,
    required this.dbPath,
    required this.tempPath,
  });

  // Returns the logs directory as a Directory object
  Directory get logsDirectory => Directory(logsPath);

  // Returns the database directory as a Directory object
  Directory get databaseDirectory => Directory(dbPath);

  // Returns the temp directory
  Directory get tempDirectory => Directory(tempPath);

  // Access specific files
  // File coreFile() {
  //   return File(p.join(logsPath, 'box.log'));
  // }

  File appLogFile() {
    return File(p.join(logsPath, 'lantern.log'));
  }

  @override
  String toString() {
    return 'PathManager(logsPath: $logsPath, dbPath: $dbPath, tempPath: $tempPath)';
  }
}
