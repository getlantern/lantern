import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/entity/app_setting_entity.dart';
import 'package:lantern/core/models/entity/server_location_entity.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/core/services/local_storage.dart';

class FakeLocalStorageService extends LocalStorageService {
  final List<PrivateServerEntity> _servers = [];
  ServerLocationEntity _selected = ServerLocationEntity(
    autoSelect: true,
    serverLocation: '',
    serverName: '',
    serverType: ServerLocationType.auto.name,
    autoLocation: AutoLocationEntity(
      serverLocation: 'fastest_server'.i18n,
      serverName: '',
    ),
  );
  AppSetting? _appSetting;

  PrivateServerEntity? lastSaved;

  @override
  Future<void> init() async {}
  @override
  void close() {}
  @override
  void updateInitialServerLocation() {}

  @override
  void updateAppSetting(AppSetting appSetting) {
    _appSetting = appSetting;
  }

  @override
  AppSetting? getAppSetting() => _appSetting;

  @override
  Future<void> savePrivateServer(PrivateServerEntity server) async {
    _servers.removeWhere((s) => s.serverName == server.serverName);
    _servers.add(server);
    lastSaved = server;
  }

  @override
  List<PrivateServerEntity> getPrivateServer() => List.unmodifiable(_servers);

  @override
  void updatePrivateServerName(String serverName, String newName) {
    final i = _servers.indexWhere((s) => s.serverName == serverName);
    if (i != -1) {
      _servers[i] = _servers[i].copyWith(serverName: newName);
    }
  }

  @override
  Future<void> deletePrivateServer(String serverName) async {
    _servers.removeWhere((s) => s.serverName == serverName);
  }

  @override
  Future<void> saveServerLocation(ServerLocationEntity server) async {
    _selected = server;
  }

  @override
  ServerLocationEntity getSavedServerLocations() => _selected;
}
