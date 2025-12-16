import 'dart:io';

import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/core/models/entity/app_setting_entity.dart';
import 'package:lantern/core/models/entity/developer_mode_entity.dart';
import 'package:lantern/core/models/entity/plan_entity.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/core/models/entity/server_location_entity.dart';
import 'package:lantern/core/models/entity/user_entity.dart';
import 'package:lantern/core/models/entity/website.dart';
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:path/path.dart' as p;

import '../../lantern/protos/protos/auth.pb.dart';
import 'db/objectbox.g.dart';

/// LocalStorageService is responsible for managing local storage operations
class LocalStorageService {
  late Store _store;

  late Box<DeveloperModeEntity> _developerModeBox;
  late Box<AppSetting> _appSettingBox;
  late Box<AppData> _appsBox;
  late Box<Website> _websitesBox;
  late Box<PlansDataEntity> _plansBox;
  late Box<UserResponseEntity> _userBox;
  late Box<PrivateServerEntity> _privateServerBox;
  late Box<ServerLocationEntity> _serverLocationBox;

  ///Due to limitations in macOS the value must be at most 19 characters
  /// Do not change this value
  final macosApplicationGroup = AppSecrets.macosAppGroupId;

  Future<void> init() async {
    final start = DateTime.now();
    dbLogger.debug("Initializing LocalStorageService");
    final docsDir = await AppStorageUtils.getAppDirectory();
    final dbPath = p.join(docsDir.path, "objectbox-db");
    dbLogger.debug("Using ObjectBox DB path: $dbPath");

    try {
      dbLogger.debug("Checking if DB directory exists...");
      await openCleanStore(dbPath);
    } on ObjectBoxException catch (e, s) {
      dbLogger.error("Error opening ObjectBox store", e, s);
      final error = e.message;
      //Ex
      //failed to create store: DB's last property ID XX is higher than the incoming one XX in entity XXX
      if (error.contains("failed to create store") ||
          error.contains("DB's last property ID")) {
        dbLogger.warning(
            "ObjectBox schema mismatch detected – wiping old DB…", e);

        // delete the entire store directory
        final dir = Directory(dbPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        await openCleanStore(dbPath);
      } else {
        rethrow;
      }
    }

    _appSettingBox = _store.box<AppSetting>();
    _appsBox = _store.box<AppData>();
    _websitesBox = _store.box<Website>();
    _plansBox = _store.box<PlansDataEntity>();
    _userBox = _store.box<UserResponseEntity>();
    _privateServerBox = _store.box<PrivateServerEntity>();
    _serverLocationBox = _store.box<ServerLocationEntity>();
    _developerModeBox = _store.box<DeveloperModeEntity>();
    updateInitialServerLocation();

    dbLogger.info(
        "LocalStorageService initialized in ${DateTime.now().difference(start).inMilliseconds}ms");
  }

  Future<void> openCleanStore(String dbPath) async {
    if (!await Directory(dbPath).exists()) {
      dbLogger.debug("DB directory does not exist. Creating...");
      await Directory(dbPath).create(recursive: true);
    }

    dbLogger.debug("Opening ObjectBox store...");
    _store = await openStore(
      directory: dbPath,
      macosApplicationGroup: macosApplicationGroup,
    );
    dbLogger.debug("ObjectBox store opened successfully.");
  }

  void close() {
    _store.close();
  }

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

  // Select all apps (set isEnabled = true)
  Future<void> selectAllApps() async {
    final apps = _appsBox.getAll();
    for (var app in apps) {
      app.isEnabled = true;
    }
    await _appsBox.putManyAsync(apps);
  }

// Deselect all apps (set isEnabled = false)
  Future<void> deselectAllApps() async {
    final apps = _appsBox.getAll();
    for (var app in apps) {
      app.isEnabled = false;
    }
    await _appsBox.putManyAsync(apps);
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
  void saveUser(UserResponseEntity user) {
    try {
      _userBox.removeAll();
      _userBox.putAsync(user);
    } catch (e) {
      appLogger.error("Error saving user to local storage", e);
    }
  }

  UserResponse? getUser() {
    try {
      final user = _userBox.getAll();
      return user.isEmpty ? null : user.first.toUserResponse();
    } catch (e) {
      appLogger.error("Error getting user from local storage", e);
      return null;
    }
  }

  void updateAppSetting(AppSetting appSetting) {
    _appSettingBox.put(appSetting);
  }

  AppSetting? getAppSetting() {
    final appSetting = _appSettingBox.getAll();
    return appSetting.isEmpty ? null : appSetting.first;
  }

  // Private Server methods
  Future<void> savePrivateServer(PrivateServerEntity server) async {
    _privateServerBox.putAsync(server);
  }

  List<PrivateServerEntity> getPrivateServer() {
    final server = _privateServerBox.getAll();
    return server.isEmpty ? [] : server;
  }

  void updatePrivateServerName(String serverName, String newName) async {
    final existing = _privateServerBox
        .query(PrivateServerEntity_.serverName.equals(serverName.toLowerCase()))
        .build()
        .findFirst();
    if (existing != null) {
      final newInstance = existing.copyWith(
        serverName: newName,
      );
      _privateServerBox.put(newInstance, mode: PutMode.update);
      return;
    }
    throw Exception("Private server with name $serverName does not exist");
  }

  Future<void> deletePrivateServer(String serverName) async {
    final existing = _privateServerBox
        .query(PrivateServerEntity_.serverName.equals(serverName))
        .build()
        .findFirst();
    if (existing != null) {
      await _privateServerBox.removeAsync(existing.id);
      return;
    }
    throw Exception("Private server with name $serverName does not exist");
  }

  //Server Location methods

  void updateInitialServerLocation() {
    final server = _serverLocationBox.getAll();
    if (server.isEmpty) {
      _serverLocationBox.put(initialServerLocation());
    }
  }

  void saveServerLocation(ServerLocationEntity server) {
    _serverLocationBox.removeAll();
    _serverLocationBox.put(server);
  }

  ServerLocationEntity getSavedServerLocations() {
    final server = _serverLocationBox.getAll();
    return server.isEmpty
        ? ServerLocationEntity(
            autoSelect: true,
            serverName: '',
            serverType: ServerLocationType.auto.name,
            country: '',
            city: '',
            displayName: 'fastest_server'.i18n,
            countryCode: '',
          )
        : server.first;
  }

  /// Developer Mode methods
  void updateDeveloperSetting(DeveloperModeEntity devSetting) {
    _developerModeBox.removeAll();
    _developerModeBox.put(devSetting);
  }

  DeveloperModeEntity? getDeveloperSetting() {
    final devSetting = _developerModeBox.getAll();
    return devSetting.isEmpty ? null : devSetting.first;
  }
}
