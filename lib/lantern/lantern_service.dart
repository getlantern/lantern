import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import '../core/common/common.dart';

///LanternService is wrapper around native and ffi services
/// all communication happens here
class LanternService implements LanternCoreService {
  final LanternFFIService _ffiService;

  final LanternPlatformService _platformService;
  final AppPurchase _appPurchase;

  LanternService({
    required LanternFFIService ffiService,
    required LanternPlatformService platformService,
    required AppPurchase appPurchase,
  })  : _appPurchase = appPurchase,
        _platformService = platformService,
        _ffiService = ffiService;

  @override
  Future<Either<Failure, String>> startVPN() async {
    if (PlatformUtils.isDesktop) {
      return ffiService.startVPN();
    }
    return _platformService.startVPN();
  }

  @override
  Future<Either<Failure, String>> stopVPN() {
    if (PlatformUtils.isDesktop) {
      return ffiService.stopVPN();
    }
    return _platformService.stopVPN();
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    if (!PlatformUtils.isDesktop) {
      throw UnimplementedError();
    }
    yield* ffiService.appsDataStream();
  }

  @override
  Stream<List<String>> logsStream() async* {
    if (!PlatformUtils.isDesktop) {
      throw UnimplementedError();
    }
    yield* ffiService.logsStream();
  }

  @override
  Future<void> init() {
    if (PlatformUtils.isDesktop) {
      return ffiService.init();
    }
    return _platformService.init();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    if (PlatformUtils.isDesktop) {
      return ffiService.watchVPNStatus();
    }
    return _platformService.watchVPNStatus();
  }

  @override
  Future<Either<Failure, Unit>> isVPNConnected() {
    return _platformService.isVPNConnected();
  }

  @override
  Future<Either<Failure, Unit>> cancelSubscription() {
    // TODO: implement cancelSubscription
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> makeOneTimePayment({required String planID}) {
    // TODO: implement makeOneTimePayment
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> subscribeToPlan({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) {
    if (PlatformUtils.isDesktop()) {
      throw UnimplementedError();
    }
    return _platformService.subscribeToPlan(
      planId: planId,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required StipeSubscriptionType type, required String planId}) {
    if (PlatformUtils.isDesktop()) {
      return _ffiService.stipeSubscriptionPaymentRedirect(
          type: type, planId: planId);
    }
    return _platformService.stipeSubscriptionPaymentRedirect(
        type: type, planId: planId);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId}) {
    if (PlatformUtils.isDesktop()) {
      throw UnimplementedError();
    } else {
      return _platformService.stipeSubscription(planId: planId);
    if (PlatformUtils.isDesktop) {
      return ffiService.isVPNConnected();
    }
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value) {
    if (PlatformUtils.isDesktop) {
      return ffiService.addSplitTunnelItem(type, value);
    }
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value) {
    if (PlatformUtils.isDesktop) {
      return ffiService.removeSplitTunnelItem(type, value);
    }
    throw UnimplementedError();
  }
}
