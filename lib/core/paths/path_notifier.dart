import 'dart:io';

import 'package:lantern/core/paths/path_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'path_notifier.g.dart';

@Riverpod()
class PathNotifier extends _$PathNotifier {
  @override
  Future<PathManager> build() async {
    final logsDirectory = await getLogsDirectory();
    final dbDirectory = await getDBDirectory();
    final tempDirectory = await getTemporaryDirectory();

    final logsPath = p.join(logsDirectory.path, 'Logs', 'Lantern');
    final dbPath = p.join(dbDirectory.path, 'objectbox-db');
    final tempPath = tempDirectory.path;

    final path = PathManager(
      logsPath: logsPath,
      dbPath: dbPath,
      tempPath: tempPath,
    );
    return path;
  }

  Future<Directory> getLogsDirectory() async {
    if (Platform.isIOS || Platform.isMacOS) {
      return getLibraryDirectory();
    } else if (Platform.isWindows || Platform.isLinux) {
      return getApplicationSupportDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> getDBDirectory() {
    if (Platform.isIOS || Platform.isAndroid) {
      return getApplicationDocumentsDirectory();
    } else {
      return getApplicationSupportDirectory();
    }
  }
}
