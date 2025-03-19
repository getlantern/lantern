import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

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
  Future<void> startVPN() {
    // TODO: implement startVPN
    throw UnimplementedError();
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
