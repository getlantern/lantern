import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
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
    if (PlatformUtils.isDesktop()) {
      return _ffiService.startVPN();
    }
    return _platformService.startVPN();
  }

  @override
  Future<Either<Failure, String>> stopVPN() {
    if (PlatformUtils.isDesktop()) {
      return _ffiService.stopVPN();
    }
    return _platformService.stopVPN();
  }

  @override
  Future<void> init() {
    if (PlatformUtils.isDesktop()) {
      return _ffiService.init();
    }
    return _platformService.init();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    if (PlatformUtils.isDesktop()) {
      return _ffiService.watchVPNStatus();
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
    }
  }
}
