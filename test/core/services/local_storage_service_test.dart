// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakePathProvider extends PathProviderLinux {
  _FakePathProvider(this.dir);

  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  late Directory dir;
  late File prefsFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lantern_prefs_test');
    prefsFile = File(p.join(dir.path, 'shared_preferences.json'));
    SharedPreferencesAsyncPlatform.instance = SharedPreferencesAsyncLinux()
      ..pathProvider = _FakePathProvider(dir.path);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  LocalStorageService newStorage() =>
      LocalStorageService(supportDir: () async => dir);

  test('init reads an intact prefs file', () async {
    prefsFile.writeAsStringSync('{"rating_prompt_sessions":"1"}');

    final storage = newStorage();
    await storage.init();

    expect(storage.getString('rating_prompt_sessions'), '1');
    expect(File('${prefsFile.path}.corrupt').existsSync(), isFalse);
  });

  test('init sets a corrupted prefs file aside and starts empty', () async {
    const corrupted = '{"rating_prompt_sessions":"1"}ull,"plans_json":null}';
    prefsFile.writeAsStringSync(corrupted);

    final storage = newStorage();
    await storage.init();

    expect(storage.getString('rating_prompt_sessions'), isNull);
    expect(File('${prefsFile.path}.corrupt').readAsStringSync(), corrupted);

    await storage.setString('rating_prompt_sessions', '2');
    expect(storage.getString('rating_prompt_sessions'), '2');
  });
}
