import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import '../core/common/common.dart';

///LanternService is wrapper around native and ffi services
/// all communication happens here
class LanternService implements LanternCoreService {
  final LanternFFIService ffiService;

  final LanternPlatformService nativeBridge;

  LanternService({
    required this.ffiService,
    required this.nativeBridge,
  });

  @override
  Future<Either<Failure, Unit>> startVPN() async {
    if (PlatformUtils.isDesktop()) {
      throw UnimplementedError();
    }
    return nativeBridge.startVPN();
  }

  @override
  Future<void> stopVPN() {
    // TODO: implement stopVPN
    throw UnimplementedError();
  }

  @override
  Future<Either<String, Unit>> setupRadiance() {
    return ffiService.setupRadiance();
  }
}
