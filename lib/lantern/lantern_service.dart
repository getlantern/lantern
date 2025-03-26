import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import '../core/common/common.dart';

///LanternService is wrapper around native and ffi services
/// all communication happens here
class LanternService implements LanternCoreService {
  final LanternFFIService ffiService;

  final LanternPlatformService platformService;

  LanternService({
    required this.ffiService,
    required this.platformService,
  });

  @override
  Future<Either<Failure, String>> startVPN() async {
    if (PlatformUtils.isDesktop()) {
      throw UnimplementedError();
    }
    return platformService.startVPN();
  }

  @override
  Future<Either<Failure, String>> stopVPN() {
    if (PlatformUtils.isDesktop()) {
      throw UnimplementedError();
    }
    return platformService.stopVPN();
  }

  @override
  Future<Either<String, Unit>> setupRadiance() {
    return ffiService.setupRadiance();
  }

  @override
  Future<void> init() {
    if (PlatformUtils.isDesktop()) {
      return ffiService.init();
    }
    return platformService.init();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    if (PlatformUtils.isDesktop()) {
      throw UnimplementedError();
    }
    return platformService.watchVPNStatus();
  }
}
