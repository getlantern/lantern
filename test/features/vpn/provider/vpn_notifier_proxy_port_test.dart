import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/common/stealth_no_vpn_proxy.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  final calls = <String>[];
  final ports = <int>[];

  @override
  Future<Either<Failure, bool>> isVPNConnected() async => right(false);

  @override
  Future<Either<Failure, Unit>> setProxyListenPort(int port) async {
    ports.add(port);
    calls.add('port');
    return right(unit);
  }

  @override
  Future<Either<Failure, String>> stopVPN() async {
    calls.add('stop');
    return right('ok');
  }

  @override
  Future<Either<Failure, String>> startVPN() async {
    calls.add('start');
    return right('ok');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements LocalStorageService {
  final values = <String, String>{};
  @override
  String? getString(String key) => values[key];
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications implements NotificationService {
  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    NotificationType notificationType = NotificationType.main,
    String? payload,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Status extends VPNStatusNotifier {
  _Status(this.stream);
  final Stream<LanternStatus> stream;
  @override
  Stream<LanternStatus> build() => stream;
}

class _Location extends ServerLocationNotifier {
  @override
  ServerLocation build() =>
      ServerLocation(serverName: '', serverType: ServerLocationType.auto.name);
}

class _AppSetting extends AppSettingNotifier {
  @override
  AppSetting build() => AppSetting();
  @override
  void setSuccessfulConnection(bool value) {}
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Service service;
  late StreamController<LanternStatus> status;
  late ProviderContainer c;

  setUp(() async {
    await sl.reset();
    sl.registerSingleton<LocalStorageService>(_Storage());
    sl.registerSingleton<NotificationService>(_Notifications());
    service = _Service();
    status = StreamController<LanternStatus>.broadcast(sync: true);
  });

  tearDown(() async {
    c.dispose();
    await status.close();
    await sl.reset();
  });

  // Built inside each test so its futures run in that test's zone, which for
  // testWidgets is fake time.
  void listen() {
    c = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        vPNStatusProvider.overrideWith(() => _Status(status.stream)),
        serverLocationProvider.overrideWith(_Location.new),
        appSettingProvider.overrideWith(_AppSetting.new),
      ],
    );
    c.listen(vpnProvider, (_, _) {});
  }

  Future<void> start() async {
    listen();
    await _settle();
  }

  void emit(VPNStatus s) => status.add(LanternStatus(status: s));

  test('a running proxy restarts on the saved port', () async {
    await start();
    emit(VPNStatus.connected);
    await StealthNoVpnProxy.setPort(20000);

    final change = c.read(vpnProvider.notifier).applyProxyPort();
    await _settle();
    expect(service.ports, [20000]);
    expect(service.calls, ['port', 'stop']);

    // The start waits for the native stop to finish.
    emit(VPNStatus.disconnected);
    await change;
    expect(service.calls, ['port', 'stop', 'start']);
  });

  test('a proxy that is still starting restarts once it connects', () async {
    await start();
    emit(VPNStatus.connecting);
    await StealthNoVpnProxy.setPort(20001);

    final change = c.read(vpnProvider.notifier).applyProxyPort();
    await _settle();
    expect(service.calls, ['port']);

    emit(VPNStatus.connected);
    await _settle();
    expect(service.calls, ['port', 'stop']);

    emit(VPNStatus.disconnected);
    await change;
    expect(service.calls, ['port', 'stop', 'start']);
  });

  // testWidgets runs on fake time, so the start can outlast any deadline.
  testWidgets('a slow start still restarts on the new port', (tester) async {
    listen();
    await tester.pump();
    emit(VPNStatus.connecting);
    await StealthNoVpnProxy.setPort(20004);
    var done = false;
    unawaited(
      c.read(vpnProvider.notifier).applyProxyPort().then((_) => done = true),
    );
    // Longer than the native start window.
    await tester.pump(const Duration(seconds: 90));
    expect(service.calls, ['port']);

    emit(VPNStatus.connected);
    await tester.pump();
    expect(service.calls, ['port', 'stop']);
    emit(VPNStatus.disconnected);
    await tester.pump();
    expect(service.calls, ['port', 'stop', 'start']);
    expect(done, isTrue);
  });

  test('a stopped proxy only takes the port for its next start', () async {
    await start();
    emit(VPNStatus.disconnected);
    await StealthNoVpnProxy.setPort(20002);

    await c.read(vpnProvider.notifier).applyProxyPort();
    expect(service.calls, ['port']);
  });
}
