import 'dart:convert';

import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';
import 'package:lantern/core/split_tunneling/apps_data_provider.dart';
import 'package:objectbox/objectbox.dart';
import 'package:lantern/core/services/db/objectbox.g.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'injection_container.dart';

class AppDB {
  static final LocalStorageService _localStorageService =
      sl<LocalStorageService>();

  static set<T>(String key, T value) {
    assert(T != dynamic, "You must explicitly specify a type for set<T>()");
    final start = DateTime.now();
    _localStorageService.set(key, value);
    dbLogger.info(
        "Key: $key saved successfully in ${DateTime.now().difference(start).inMilliseconds}ms");
  }

  static T? get<T>(String key) {
    return _localStorageService.get<T>(key);
  }
}

class LocalStorageService {
  late Store _store;

  late Box<AppDatabase> _box;
  late Box<AppData> _appsBox;

  late AppDatabase _appDb;

  /// In-memory cache
  static late Map<String, dynamic> _cache;

  ///Due to limitations in macOS the value must be at most 19 characters
  /// Do not change this value
  final macosApplicationGroup = AppSecrets.macosAppGroupId;

  Future<void> init() async {
    final start = DateTime.now();
    dbLogger.debug("Initializing LocalStorageService");
    final docsDir = await getApplicationDocumentsDirectory();
    _store = await openStore(
        directory: p.join(docsDir.path, "objectbox-db"),
        macosApplicationGroup: macosApplicationGroup);

    _box = _store.box<AppDatabase>();
    _appsBox = _store.box<AppData>();

    AppDatabase? db = _box.get(1);
    if (db == null) {
      db = AppDatabase(data: "{}")..id = 1;
      _box.put(db);
    }
    _appDb = db;
    _cache = _appDb.map;
    dbLogger.info(
        "LocalStorageService initialized in ${DateTime.now().difference(start).inMilliseconds}ms");
  }

  void close() {
    _store.close();
  }

  T? get<T>(String key) {
    dbLogger.debug("Getting key: $key");
    return _cache[key] as T?;
    // final Map<String, dynamic> dbMap = _appDb.map;
    // return dbMap[key] as T?;
  }

  /// Save a key-value pair
  void set<T>(String key, T value) {
    try {
      final Map<String, dynamic> dbMap = _appDb.map;
      dbMap[key] = value;
      _appDb.map = dbMap;
      _box.putAsync(_appDb);
      //update cache
      _cache[key] = value;
    } catch (e) {
      dbLogger.error("Error saving key: $key, value: $value");
    }
  }

  /// Remove a key
  void remove(String key) {
    final Map<String, dynamic> dbMap = _appDb.map;
    dbMap.remove(key);
    _appDb.map = dbMap;
    _box.put(_appDb);
    dbLogger.debug("Key: $key removed successfully");
  }

  // Apps methods
  void saveApps(Set<AppData> apps) {
    _appsBox.removeAll();
    _appsBox.putMany(apps.toList());
  }

  Set<AppData> getEnabledApps() {
    return _appsBox.getAll().where((a) => a.isEnabled).toSet();
  }

  void toggleApp(AppData app) {
    final existing =
        _appsBox.query(AppData_.name.equals(app.name)).build().findFirst();

    if (existing != null) {
      _appsBox.remove(existing.id);
    } else {
      _appsBox.put(app.copyWith(isEnabled: true));
    }
  }
}

@Entity()
class AppDatabase {
  @Id(assignable: true)
  int id = 0;

  String data;

  AppDatabase({required this.data});

  /// Convert JSON string to Map<String, dynamic>
  Map<String, dynamic> get map => jsonDecode(data);

  /// Convert Map<String, dynamic> to JSON string
  set map(Map<String, dynamic> newData) {
    data = jsonEncode(newData);
  }
}
