import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/models/plan_entity.dart';
import 'package:lantern/core/models/private_server_entity.dart';
import 'package:lantern/core/models/server_location_entity.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:path/path.dart' as p;

import '../../lantern/protos/protos/auth.pb.dart';
import '../models/user_entity.dart';
import 'db/objectbox.g.dart';

/// LocalStorageService is responsible for managing local storage operations
class LocalStorageService {
  late Store _store;

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

    try {
      _store = await openStore(
        directory: dbPath,
        macosApplicationGroup: macosApplicationGroup,
      );
    } on ObjectBoxException catch (e) {
      final error = e.message;
      //Ex
      //failed to create store: DB's last property ID XX is higher than the incoming one XX in entity XXX
      if (kDebugMode &&
          (error.contains("failed to create store") ||
              error.contains("DB's last property ID"))) {
        dbLogger.warning(
            "ObjectBox schema mismatch detected – wiping old DB…", e);

        // delete the entire store directory
        final dir = Directory(dbPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }

        // Retry after wiping the old schema-mismatched DB
        _store = await openStore(
          directory: dbPath,
          macosApplicationGroup: macosApplicationGroup,
        );
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
    updateInitialServerLocation();

    dbLogger.info(
        "LocalStorageService initialized in ${DateTime.now().difference(start).inMilliseconds}ms");
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
    _userBox.removeAll();
    _userBox.putAsync(user);
  }

  UserResponse? getUser() {
    final user = _userBox.getAll();
    return user.isEmpty ? null : user.first.toUserResponse();
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

  PrivateServerEntity? defaultPrivateServer() {
    final server = _privateServerBox
        .query(PrivateServerEntity_.userSelected.equals(true))
        .build()
        .findFirst();
    return server;
  }

  void setDefaultPrivateServer(String serverName) {
    final servers = _privateServerBox.getAll();

    for (var server in servers) {
      final isSelected = server.serverName == serverName;
      server.userSelected = isSelected;
      _privateServerBox.put(server);
    }
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
      _privateServerBox.put(newInstance,mode: PutMode.update);
      return;
    }
    throw Exception("Private server with name $serverName does not exist");
  }

  Future<void> deletePrivateServer(String serverName) async {
    final existing = _privateServerBox
        .query(PrivateServerEntity_.serverName.equals(serverName.toLowerCase()))
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
      final initialServer = ServerLocationEntity(
        autoSelect: true,
        serverLocation: 'Fastest Country',
        serverName: '',
        serverType: ServerLocationType.auto.name,
      );
      _serverLocationBox.put(initialServer);
    }
  }

  Future<void> saveServerLocation(ServerLocationEntity server) async {
    _serverLocationBox.removeAll();
    await _serverLocationBox.putAsync(server);
  }

  ServerLocationEntity getServerLocations() {
    final server = _serverLocationBox.getAll();
  return server.isEmpty
        ? ServerLocationEntity(
            autoSelect: true,
            serverLocation: 'Fastest Country',
            serverName: '',
            serverType: ServerLocationType.auto.name,
          )
        : server.first;
  }
}
