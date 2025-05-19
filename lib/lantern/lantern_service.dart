import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../core/common/common.dart';

///LanternService is wrapper around native and ffi services
/// all communication happens here
class LanternService implements LanternCoreService {
  final LanternFFIService _ffiService;

  final LanternPlatformService _platformService;

  LanternService({
    required LanternFFIService ffiService,
    required LanternPlatformService platformService,
    required AppPurchase appPurchase,
  })  : _platformService = platformService,
        _ffiService = ffiService;

  @override
  Future<Either<Failure, String>> startVPN() async {
    if (PlatformUtils.isDesktop) {
      return _ffiService.startVPN();
    }
    return _platformService.startVPN();
  }

  @override
  Future<Either<Failure, String>> stopVPN() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.stopVPN();
    }
    return _platformService.stopVPN();
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    if (PlatformUtils.isDesktop) {
      yield* _ffiService.appsDataStream();
    } else {
      yield* _platformService.appsDataStream();
    }
  }

  @override
  Future<void> init() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.init();
    }
    return _platformService.init();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.watchVPNStatus();
    }
    return _platformService.watchVPNStatus();
  }

  @override
  Stream<List<String>> watchLogs(String path) {
    if (PlatformUtils.isDesktop) {
      throw UnimplementedError();
    }
    return _platformService.watchLogs(path);
  }

  @override
  Future<Either<Failure, Unit>> isVPNConnected() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.isVPNConnected();
    }
    return _platformService.isVPNConnected();
  }

  @override
  Future<Either<Failure, Unit>> startInAppPurchaseFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) {
    if (PlatformUtils.isDesktop) {
      throw UnimplementedError();
    }
    return _platformService.startInAppPurchaseFlow(
      planId: planId,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required StipeSubscriptionType type,
      required String planId,
      required String email}) {
    if (PlatformUtils.isDesktop) {
      return _ffiService.stipeSubscriptionPaymentRedirect(
        type: type,
        planId: planId,
        email: email,
      );
    }
    return throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId, required String email}) {
    if (PlatformUtils.isDesktop) {
      throw UnimplementedError();
    }
    return _platformService.stipeSubscription(planId: planId, email: email);
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value) {
    if (PlatformUtils.isDesktop) {
      return _ffiService.addSplitTunnelItem(type, value);
    }
    return _platformService.addSplitTunnelItem(type, value);
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value) {
    if (PlatformUtils.isDesktop) {
      return _ffiService.removeSplitTunnelItem(type, value);
    }
    return _platformService.removeSplitTunnelItem(type, value);
  }

  @override
  Future<Either<Failure, PlansData>> plans() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.plans();
    }
    return _platformService.plans();
  }

  @override
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider) {
    if (PlatformUtils.isDesktop) {
      return _ffiService.getOAuthLoginUrl(provider);
    }
    return _platformService.getOAuthLoginUrl(provider);
  }

  @override
  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token) {
    if (PlatformUtils.isDesktop) {
      return _ffiService.oAuthLoginCallback(token);
    }
    return _platformService.oAuthLoginCallback(token);
  }

  @override
  Future<Either<Failure, UserResponse>> getUserData() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.getUserData();
    }
    return _platformService.getUserData();
  }

  @override
  Future<Either<Failure, String>> stripeBillingPortal() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.stripeBillingPortal();
    }
    return _platformService.stripeBillingPortal();
  }

  @override
  Future<Either<Failure, Unit>> showManageSubscriptions() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.showManageSubscriptions();
    }
    return _platformService.showManageSubscriptions();
  }

  @override
  Future<Either<Failure, UserResponse>> fetchUserData() {
    if (PlatformUtils.isDesktop) {
      return _ffiService.fetchUserData();
    }
    return _platformService.fetchUserData();
  }
}
