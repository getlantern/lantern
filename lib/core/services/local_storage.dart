import 'dart:convert';
import 'dart:io';

import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/models/plan_entity.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../lantern/protos/protos/auth.pb.dart';
import '../models/user_entity.dart';
import 'db/objectbox.g.dart';
import 'injection_container.dart';

// class AppDB {
//   static final LocalStorageService _localStorageService =
//       sl<LocalStorageService>();
//
//   static set<T>(String key, T value) {
//     assert(T != dynamic, "You must explicitly specify a type for set<T>()");
//     final start = DateTime.now();
//     _localStorageService.set(key, value);
//     dbLogger.info(
//       "Key: $key saved successfully in ${DateTime.now().difference(start).inMilliseconds}ms",
//     );
//   }
//
//   static T? get<T>(String key) {
//     return _localStorageService.get<T>(key);
//   }
// }

class LocalStorageService {
  late Store _store;

  late Box<AppSetting> _appSettingBox;
  late Box<AppData> _appsBox;
  late Box<Website> _websitesBox;
  late Box<PlansDataEntity> _plansBox;
  late Box<LoginResponseEntity> _userBox;

  ///Due to limitations in macOS the value must be at most 19 characters
  /// Do not change this value
  final macosApplicationGroup = AppSecrets.macosAppGroupId;

  Future<void> init() async {
    final start = DateTime.now();
    dbLogger.debug("Initializing LocalStorageService");
    final docsDir = await AppStorageUtils.getAppDirectory();
    _store = await openStore(
      directory: p.join(docsDir.path, "objectbox-db"),
      macosApplicationGroup: macosApplicationGroup,
    );

    _appSettingBox = _store.box<AppSetting>();
    _appsBox = _store.box<AppData>();
    _websitesBox = _store.box<Website>();
    _plansBox = _store.box<PlansDataEntity>();
    _userBox = _store.box<LoginResponseEntity>();

    dbLogger.info(
      "LocalStorageService initialized in ${DateTime.now().difference(start).inMilliseconds}ms",
    );
  }

  void close() {
    _store.close();
  }

  // T? get<T>(String key) {
  //   dbLogger.debug("Getting key: $key");
  //   return _cache[key] as T?;
  //   // final Map<String, dynamic> dbMap = _appDb.map;
  //   // return dbMap[key] as T?;
  // }
  //
  // /// Save a key-value pair
  // void set<T>(String key, T value) {
  //   try {
  //     final Map<String, dynamic> dbMap = _appDb.map;
  //     dbMap[key] = value;
  //     _appDb.map = dbMap;
  //     _box.putAsync(_appDb);
  //     //update cache
  //     _cache[key] = value;
  //   } catch (e) {
  //     dbLogger.error("Error saving key: $key, value: $value");
  //   }
  // }

  // /// Remove a key
  // void remove(String key) {
  //   final Map<String, dynamic> dbMap = _appDb.map;
  //   dbMap.remove(key);
  //   _appDb.map = dbMap;
  //   _box.put(_appDb);
  //   dbLogger.debug("Key: $key removed successfully");
  // }

  // Apps methods
  Future<void> saveApps(Set<AppData> apps) async {
    await _appsBox.removeAllAsync();
    await _appsBox.putManyAsync(apps.toList());
  }

  Set<AppData> getEnabledApps() {
    return _appsBox.getAll().where((a) => a.isEnabled).toSet();
  }

  Set<AppData> getAllApps() {
    return _appsBox.getAll().toSet();
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

  // Website methods
  Future<void> saveWebsites(Set<Website> websites) async {
    await _websitesBox.removeAllAsync();
    await _websitesBox.putManyAsync(websites.toList());
  }

  Set<Website> getEnabledWebsites() {
    return _websitesBox.getAll().toSet();
  }

  // Plans methods
  void savePlans(PlansDataEntity plans) {
    _plansBox.removeAll();
    _plansBox.put(plans);
  }

  PlansDataEntity? getPlans() {
    final plans = _plansBox.getAll();
    return plans.isEmpty ? null : plans.first;
  }

  // User methods
  void saveUser(LoginResponseEntity user) {
    _userBox.removeAll();
    _userBox.put(user);
  }

  LoginResponse? getUser() {
    final user = _userBox.getAll();
    return user.isEmpty ? null : user.first.toLoginResponse();
  }

  void updateAppSetting(AppSetting appSetting) {
    _appSettingBox.put(appSetting);
  }
  AppSetting? getAppSetting() {
    final appSetting = _appSettingBox.getAll();
    return appSetting.isEmpty ? null : appSetting.first;
  }
}
