import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart'
    show AppDataEventType, AppDataEvent;
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/app_data_utils.dart';
import 'package:lantern/core/utils/enabled_apps.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../core/models/lantern_status.dart';
import '../core/services/injection_container.dart' show sl;

class LanternPlatformService implements LanternCoreService {
  LanternPlatformService();

  static const channelPrefix = 'org.getlantern.lantern';
  static const MethodChannel _methodChannel =
      MethodChannel('$channelPrefix/method');
  static const logsChannel = EventChannel("$channelPrefix/logs");
  static const EventChannel statusChannel =
      EventChannel("$channelPrefix/status", JSONMethodCodec());
  static const EventChannel systemExtensionStatusChannel =
      EventChannel("$channelPrefix/system_extension_status", JSONMethodCodec());
  static const privateServerStatusChannel =
      EventChannel("$channelPrefix/private_server_status", JSONMethodCodec());
  static const appEventStatusChannel =
      EventChannel("$channelPrefix/app_events", JSONMethodCodec());
  static const EventChannel appStreamChannel =
      EventChannel("$channelPrefix/app_stream", JSONMethodCodec());

  late final Stream<LanternStatus> _status;
  late final Stream<PrivateServerStatus> _privateServerStatus;
  late final Stream<MacOSExtensionState> _systemExtensionStatus;
  late final Stream<AppEvent> _appEventStatus;

  final Map<String, AppData> _androidAppCache = <String, AppData>{};

  Future<void> init() async {
    appLogger.info(' LanternPlatformService');

    _status = statusChannel
        .receiveBroadcastStream()
        .map((event) => LanternStatus.fromJson(event));
    _privateServerStatus = privateServerStatusChannel
        .receiveBroadcastStream()
        .map((event) => PrivateServerStatus.fromJson(jsonDecode(event)));

    _appEventStatus = appEventStatusChannel
        .receiveBroadcastStream()
        .map((event) => AppEvent.fromJson(event));

    if (PlatformUtils.isMacOS) {
      _systemExtensionStatus = systemExtensionStatusChannel
          .receiveBroadcastStream()
          .map((event) =>
              MacOSExtensionState.fromString(event['status'].toString()));
    }
  }

  @override
  Stream<AppEvent> watchAppEvents() {
    return _appEventStatus;
  }

  @override
  Future<Either<Failure, Unit>> updateLocal(String locale) async {
    try {
      final _ = await _methodChannel.invokeMethod('updateLocale', locale);
      return Right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> updateTelemetryEvents(bool consent) async {
    try {
      final _ =
          await _methodChannel.invokeMethod('updateTelemetryEvents', consent);
      return Right(unit);
    } catch (e) {
      appLogger.error('Error updating telemetry events', e);
      return Left(e.toFailure());
    }
  }

  /// VPN methods
  @override
  Future<Either<Failure, String>> startVPN() async {
    try {
      final message = await _methodChannel.invokeMethod<String>('startVPN');
      return Right(message!);
    } on PlatformException catch (ple) {
      return Left(Failure(
          error: ple.toString(),
          localizedErrorMessage: ple.localizedDescription));
    } catch (e, stackTrace) {
      appLogger.error('Error starting VPN Flutter', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> stopVPN() async {
    try {
      final _ = await _methodChannel.invokeMethod<String>('stopVPN');
      return Right('VPN stopped');
    } on PlatformException catch (ple) {
      return Left(ple.toFailure());
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    return _status;
  }

  @override
  Stream<List<String>> watchLogs(String path) async* {
    yield* logsChannel
        .receiveBroadcastStream()
        .map((event) => (event as List).map((e) => e as String).toList());
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    if (Platform.isAndroid) {
      yield* androidAppsDataStream();
    } else if (Platform.isMacOS) {
      yield* macAppsDataStream();
    } else {
      throw UnimplementedError();
    }
  }

  @override
  Future<Either<Failure, bool>> isVPNConnected() async {
    try {
      final connected =
          await _methodChannel.invokeMethod<bool>('isVPNConnected');
      final isConnected = connected ?? false;
      return Right(isConnected);
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setBlockAdsEnabled(bool enabled) async {
    try {
      await _methodChannel
          .invokeMethod('setBlockAdsEnabled', {'enabled': enabled});
      return right(unit);
    } catch (e, st) {
      appLogger.error('setBlockAdsEnabled failed', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> isBlockAdsEnabled() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isBlockAdsEnabled');
      return right(res ?? false);
    } catch (e, st) {
      appLogger.error('isBlockAdsEnabled failed', e, st);
      return Left(e.toFailure());
    }
  }

  List<AppData> _mapToAppData(
    Iterable<Map<String, dynamic>> rawApps, {
    required EnabledAppsSnapshot enabled,
  }) {
    return rawApps.map((raw) {
      final bundleId =
          (raw["bundleId"] ?? raw["package"] ?? "").toString().trim();
      final name = (raw["name"] ?? raw["label"] ?? bundleId).toString().trim();
      final lastUpdateTime = (raw["lastUpdateTime"] as num?)?.toInt() ?? 0;
      final removed = raw["removed"] == true || raw["isRemoved"] == true;

      final key = bundleId.isNotEmpty ? bundleId : name;

      return AppData(
        bundleId: bundleId,
        name: name,
        appPath: (raw["appPath"] ?? "").toString(),
        iconPath: (raw["iconPath"] ?? "").toString(),
        iconBytes: iconToBytes(raw["icon"] ?? raw["iconBytes"]),
        lastUpdateTime: lastUpdateTime,
        removed: removed,
        isEnabled: enabled.contains(key: key, name: name),
      );
    }).toList();
  }

  Stream<List<AppData>> androidAppsDataStream() async* {
    if (!Platform.isAndroid) throw UnimplementedError();

    Stream<dynamic>? nativeStream;
    try {
      nativeStream = appStreamChannel.receiveBroadcastStream({"sizePx": 96});
    } on MissingPluginException {
      nativeStream = null;
    } catch (_) {
      nativeStream = null;
    }

    if (nativeStream == null) {
      try {
        final String? json =
            await _methodChannel.invokeMethod<String>('installedApps');
        if (json == null) {
          yield [];
          return;
        }
        final decoded = jsonDecode(json) as List<dynamic>;
        final rawApps = decoded.cast<Map<String, dynamic>>();
        final enabled = EnabledApps(sl<LocalStorageService>()).snapshot();
        for (final a in _mapToAppData(rawApps, enabled: enabled)) {
          _androidAppCache[a.bundleId] = a;
        }
        yield _sortedCache();
      } catch (e, st) {
        appLogger.error("Failed to fetch installed apps", e, st);
        yield [];
      }
      return;
    }

    try {
      await for (final ev in nativeStream) {
        if (ev is! Map) continue;
        final e = AppDataEvent.fromMap(ev);
        final enabled = EnabledApps(sl<LocalStorageService>()).snapshot();
        _applyAppDataEvent(
          type: e.type,
          items: e.items.map((a) {
            final key = a.bundleId.isNotEmpty ? a.bundleId : a.name;
            return a.copyWith(
              isEnabled: enabled.contains(key: key, name: a.name),
            );
          }).toList(),
          removed: e.removed,
        );

        yield _sortedCache();
      }
    } catch (e, st) {
      appLogger.error("App stream failed", e, st);
      yield _sortedCache();
    }
  }

  List<AppData> _applyAppDataEvent({
    required AppDataEventType type,
    required List<AppData> items,
    required List<String> removed,
  }) {
    // remove
    for (final id in removed) {
      _androidAppCache.remove(id);
    }
    // upsert
    if (type == AppDataEventType.iconReady) {
      for (final a in items) {
        final prev = _androidAppCache[a.bundleId];
        if (prev != null) {
          _androidAppCache[a.bundleId] = prev.copyWith(
            iconPath: a.iconPath,
            iconBytes: a.iconBytes,
          );
        } else {
          _androidAppCache[a.bundleId] = a;
        }
      }
    } else {
      for (final a in items) {
        _androidAppCache[a.bundleId] = a;
      }
    }

    final list = _androidAppCache.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<AppData> _sortedCache() {
    final list = _androidAppCache.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Stream<List<AppData>> macAppsDataStream() async* {
    try {
      final String? json =
          await _methodChannel.invokeMethod<String>("installedApps");
      if (json == null) {
        yield [];
        return;
      }
      final decoded = jsonDecode(json) as List<dynamic>;
      final enabled = EnabledApps(sl<LocalStorageService>()).snapshot();
      final rawApps = decoded.cast<Map<String, dynamic>>();
      yield _mapToAppData(rawApps, enabled: enabled);
    } catch (e, st) {
      appLogger.error("Failed to fetch installed apps", e, st);
      yield [];
    }
  }

  ///Split tunneling methods
  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value) async {
    try {
      await _methodChannel.invokeMethod('addSplitTunnelItem', {
        'filterType': type.value,
        'value': value,
      });
      return right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value) async {
    try {
      await _methodChannel.invokeMethod('removeSplitTunnelItem', {
        'filterType': type.value,
        'value': value,
      });
      return right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setSplitTunnelingEnabled(bool enabled) async {
    try {
      await _methodChannel
          .invokeMethod('setSplitTunnelingEnabled', {'enabled': enabled});
      return Right(unit);
    } catch (e, st) {
      appLogger.error('setSplitTunnelingEnabled failed', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> isSplitTunnelingEnabled() async {
    try {
      final enabled =
          await _methodChannel.invokeMethod<bool>('isSplitTunnelingEnabled');
      return Right(enabled ?? false);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addAllItems(
      SplitTunnelFilterType type, List<String> items) async {
    try {
      await _methodChannel.invokeMethod('addAllItems', {
        'filterType': type.value,
        'value': items.join(','),
      });
      appLogger.debug('Added all items');
      return right(unit);
    } catch (e) {
      appLogger.error('Error adding all items', e);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> removeAllItems(
      SplitTunnelFilterType type, List<String> value) async {
    try {
      appLogger.debug('Removing all items: ${value.length} items');
      await _methodChannel.invokeMethod('removeAllItems', {
        'filterType': type.value,
        'value': value.join(','),
      });
      appLogger.debug('Removed all items');
      return right(unit);
    } catch (e) {
      appLogger.error('Error removing all items', e);
      return Left(e.toFailure());
    }
  }

  /// In-App Purchase and Subscription methods
  @override
  Future<Either<Failure, Unit>> startInAppPurchaseFlow(
      {required String planId,
      required PaymentSuccessCallback onSuccess,
      required PaymentErrorCallback onError}) async {
    try {
      await sl<AppPurchase>().startSubscription(
        plan: planId,
        onSuccess: onSuccess,
        onError: onError,
      );
      return Right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required BillingType type,
      required String planId,
      required String email}) async {
    if (!PlatformUtils.isMacOS) {
      return left(Failure(
          error: 'Not supported',
          localizedErrorMessage: 'This is only supported on macOS'));
    }
    try {
      final redirectUrl = await _methodChannel
          .invokeMethod<String>('stripeSubscriptionPaymentRedirect', {
        "type": type.name,
        "planId": planId,
        "email": email,
      });
      return Right(redirectUrl!);
    } catch (e) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId, required String email}) async {
    try {
      final subData =
          await _methodChannel.invokeMethod<String>('stripeSubscription', {
        "planId": planId,
        "email": email,
      });
      final map = jsonDecode(subData!);
      return Right(map);
    } catch (e) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, String>> stripeBillingPortal() async {
    try {
      final url =
          await _methodChannel.invokeMethod<String>('stripeBillingPortal');
      return Right(url!);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, PlansData>> plans() async {
    try {
      final channel = isStoreVersion() ? 'store' : 'non-store';
      final subData =
          await _methodChannel.invokeMethod<String>('plans', channel);
      final map = jsonDecode(subData!);
      final plans = PlansData.fromJson(map);
      //Sort plans
      plans.plans.sort((a, b) {
        if (a.bestValue != b.bestValue) {
          return a.bestValue ? -1 : 1;
        }
        // Then: sort by usdPrice descending
        return b.usdPrice.compareTo(a.usdPrice);
      });

      //Sort provider
      if (PlatformUtils.isMobile) {
        plans.providers.android.sort((a, b) {
          return (b.providers.supportSubscription ? 1 : 0) -
              (a.providers.supportSubscription ? 1 : 0);
        });
      } else {
        plans.providers.desktop.sort((a, b) {
          return (b.providers.supportSubscription ? 1 : 0) -
              (a.providers.supportSubscription ? 1 : 0);
        });
      }
      return Right(plans);
    } catch (e, stackTrace) {
      appLogger.error('Error fetching plans', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, String>> paymentRedirect(
      {required String provider,
      required String planId,
      required String email}) async {
    if (PlatformUtils.isIOS) {
      throw UnimplementedError("This not supported on IOS");
    }
    try {
      final redirectUrl =
          await _methodChannel.invokeMethod<String>('paymentRedirect', {
        'provider': provider,
        'planId': planId,
        'email': email,
      });
      return Right(redirectUrl!);
    } catch (e, stackTrace) {
      appLogger.error('Error getting payment redirect URL', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  /// Only supported in IOS
  @override
  Future<Either<Failure, Unit>> showManageSubscriptions() async {
    try {
      await _methodChannel.invokeMethod('showManageSubscriptions');
      return Right(unit);
    } catch (e) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, Unit>> acknowledgeInAppPurchase(
      {required String purchaseToken, required String planId}) async {
    try {
      await _methodChannel.invokeMethod('acknowledgeInAppPurchase', {
        'purchaseToken': purchaseToken,
        'planId': planId,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error acknowledging in-app purchase', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider) async {
    try {
      final loginUrl =
          await _methodChannel.invokeMethod<String>('oauthLoginUrl', provider);
      return Right(loginUrl!);
    } catch (e) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token) async {
    try {
      final bytes =
          await _methodChannel.invokeMethod('oauthLoginCallback', token);
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error handling OAuth login callback', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  ///App related methods
  ///
  /// Get user data from local storage
  @override
  Future<Either<Failure, UserResponse>> getUserData() async {
    try {
      final bytes = await _methodChannel.invokeMethod('getUserData');
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error while getUserData user data', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  /// Fetch user data from server
  @override
  Future<Either<Failure, UserResponse>> fetchUserData() async {
    try {
      final userBytes = await _methodChannel.invokeMethod('fetchUserData');
      return Right(UserResponse.fromBuffer(userBytes));
    } catch (e, stackTrace) {
      appLogger.error("error fetching user data", e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, DataCapInfo>> getDataCapInfo() async {
    try {
      final json = await _methodChannel.invokeMethod<String>('getDataCapInfo');
      final map = jsonDecode(json!);
      final dataCap = DataCapInfo.fromJson(map);
      return Right(dataCap);
    } catch (e, st) {
      appLogger.error('fetchDataCapInfo failed', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> featureFlag() async {
    try {
      final featureFlag =
          await _methodChannel.invokeMethod<String>('featureFlag');
      return Right(featureFlag!);
    } catch (e, stackTrace) {
      appLogger.error('Error fetching feature flag', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> deviceRemove(
      {required String deviceId}) async {
    try {
      final result = await _methodChannel.invokeMethod<String>('removeDevice', {
        'deviceId': deviceId,
      });
      return Right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error removing device', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
  ) async {
    try {
      await _methodChannel.invokeMethod('reportIssue', {
        'email': email,
        'issueType': issueType,
        'description': description,
        'device': device,
        'model': model,
        'logFilePath': logFilePath,
      });
      return right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error reporting issue', e, stackTrace);
      return left(e.toFailure());
    }
  }

  /// Authentication methods
  @override
  Future<Either<Failure, UserResponse>> login(
      {required String email, required String password}) async {
    try {
      final bytes = await _methodChannel.invokeMethod('login', {
        'email': email,
        'password': password,
      });
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e) {
      appLogger.error('Error logging', e);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> logout(String email) async {
    try {
      final bytes = await _methodChannel.invokeMethod('logout', email);
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error logging out', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    try {
      await _methodChannel.invokeMethod('startRecoveryByEmail', {
        'email': email,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting recovery by email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> validateRecoveryCode(
      {required String email, required String code}) async {
    try {
      await _methodChannel.invokeMethod('validateRecoveryCode', {
        'email': email,
        'code': code,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _methodChannel.invokeMethod('completeRecoveryByEmail', {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error completing change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> signUp(
      {required String email, required String password}) async {
    try {
      await _methodChannel.invokeMethod('signUp', {
        'email': email,
        'password': password,
      });

      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error signing up', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> deleteAccount(
      {required String email, required String password}) async {
    try {
      final bytes = await _methodChannel.invokeMethod('deleteAccount', {
        'email': email,
        'password': password,
      });
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error deleting account', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> activationCode(
      {required String email, required String resellerCode}) async {
    try {
      await _methodChannel.invokeMethod('activationCode', {
        'email': email,
        'resellerCode': resellerCode,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> startChangeEmail(
      String newEmail, String password) async {
    try {
      final result =
          await _methodChannel.invokeMethod<String>('startChangeEmail', {
        'newEmail': newEmail,
        'password': password,
      });
      return Right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error starting change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> completeChangeEmail(
      {required String newEmail,
      required String password,
      required String code}) async {
    try {
      final result =
          await _methodChannel.invokeMethod<String>('completeChangeEmail', {
        'newEmail': newEmail,
        'password': password,
        'code': code,
      });
      return right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error completing change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  /// Private server methods
  @override
  Future<Either<Failure, Unit>> digitalOceanPrivateServer() async {
    try {
      await _methodChannel.invokeMethod('digitalOcean');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> googleCloudPrivateServer() async {
    try {
      await _methodChannel.invokeMethod('googleCloud');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Stream<PrivateServerStatus> watchPrivateServerStatus() {
    return _privateServerStatus;
  }

  @override
  Future<Either<Failure, Unit>> validateSession() async {
    try {
      await _methodChannel.invokeMethod("validateSession");
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating session', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setUserInput(
      {required PrivateServerInput methodType, required String input}) async {
    try {
      await _methodChannel.invokeMethod(methodType.name, input);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error setting user input', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startDeployment(
      {required String location, required String serverName}) async {
    try {
      await _methodChannel.invokeMethod('startDeployment', {
        'location': location,
        'serverName': serverName,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelDeployment() async {
    try {
      await _methodChannel.invokeMethod('cancelDeployment');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error canceling deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setCert({required String fingerprint}) async {
    try {
      await _methodChannel.invokeMethod('selectCertFingerprint', fingerprint);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error canceling deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addServerManually(
      {required String ip,
      required String port,
      required String accessToken,
      required String serverName}) async {
    try {
      await _methodChannel.invokeMethod('addServerManually', {
        'ip': ip,
        'port': port,
        'accessToken': accessToken,
        'serverName': serverName,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error canceling deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> connectToServer(
      String location, String tag) async {
    try {
      await _methodChannel.invokeMethod('connectToServer', {
        'location': location,
        'serverName': tag,
      });
      return Right("ok");
    } catch (e) {
      appLogger.debug('Error setting private server');
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> inviteToServerManagerInstance(
      {required String ip,
      required String port,
      required String accessToken,
      required String inviteName}) async {
    try {
      final inviteCode = await _methodChannel.invokeMethod<String>(
        'inviteToServerManagerInstance',
        {
          'ip': ip,
          'port': port,
          'accessToken': accessToken,
          'inviteName': inviteName,
        },
      );
      return Right(inviteCode!);
    } catch (e, stackTrace) {
      appLogger.error(
          'Error inviting to server manager instance', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> revokeServerManagerInstance(
      {required String ip,
      required String port,
      required String accessToken,
      required String inviteName}) async {
    try {
      final _ = await _methodChannel.invokeMethod<String>(
        'revokeServerManagerInstance',
        {
          'ip': ip,
          'port': port,
          'accessToken': accessToken,
          'inviteName': inviteName,
        },
      );
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error revoking server manager instance', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  ///Server location methods
  @override
  Future<Either<Failure, Server>> getAutoServerLocation() async {
    try {
      final result =
          await _methodChannel.invokeMethod<String>('getAutoServerLocation');
      return right(Server.fromJson(jsonDecode(result!)));
    } catch (e, stackTrace) {
      appLogger.error('Error fetching auto server location', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers() async {
    try {
      final result =
          await _methodChannel.invokeMethod('getLanternAvailableServers');
      final servers = AvailableServers.fromJson(jsonDecode(result));

      final outboundsByTag = {
        for (var outbound in servers.lantern.outbounds)
          outbound.tag: outbound.type
      };

      servers.lantern.locations.forEach((key, value) {
        final protoValue = outboundsByTag[key];
        if (protoValue != null) {
          value.protocol = protoValue;
        } else {
          try {
            //if not found, try to extract from tag
            value.protocol = value.tag.split('-').first;
          } catch (e) {
            //if any error, set to empty
            value.protocol = '';
          }
        }
      });
      return Right(servers);
    } catch (e, stackTrace) {
      appLogger.error(
          'Error fetching Lantern available servers', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  /// macOS System Extension methods
  @override
  Future<Either<Failure, String>> triggerSystemExtension() async {
    if (!PlatformUtils.isMacOS) {
      return left(Failure(
          error: 'Not supported',
          localizedErrorMessage: 'This is not supported only on macOS'));
    }
    try {
      final result =
          await _methodChannel.invokeMethod<String>('triggerSystemExtension');
      appLogger.info('Trigger system extension result: $result');
      return right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error triggering system extension', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> openSystemExtension() async {
    try {
      final _ = await _methodChannel
          .invokeMethod<String>('openSystemExtensionSetting');
      appLogger.info('Open System Extension Setting');
      return right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error opening system extension setting', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Stream<MacOSExtensionState> watchSystemExtensionStatus() {
    if (!PlatformUtils.isMacOS) {
      throw UnimplementedError("This is only supported on macOS");
    }
    return _systemExtensionStatus;
  }

  @override
  Future<Either<Failure, Unit>> isSystemExtensionInstalled() async {
    try {
      final _ = await _methodChannel
          .invokeMethod<String>('isSystemExtensionInstalled');
      appLogger.info('Check if system extension is installed');
      return right(unit);
    } catch (e, stackTrace) {
      appLogger.error(
          'Error checking if system extension is installed', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> attachReferralCode(String code) async {
    try {
      final result =
          await _methodChannel.invokeMethod<String>('attachReferralCode', code);
      return right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error attaching referral code', e, stackTrace);
      return Left(e.toFailure());
    }
  }
}
