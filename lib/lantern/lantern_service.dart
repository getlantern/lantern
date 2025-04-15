import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/split_tunneling/split_tunnel_filer_type.dart';
import 'package:lantern/core/utils/platform_utils.dart';
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
    if (PlatformUtils.isDesktop) {
      return ffiService.startVPN();
    }
    return platformService.startVPN();
  }

  @override
  Future<Either<Failure, String>> stopVPN() {
    if (PlatformUtils.isDesktop) {
      return ffiService.stopVPN();
    }
    return platformService.stopVPN();
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
    return platformService.init();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    if (PlatformUtils.isDesktop) {
      return ffiService.watchVPNStatus();
    }
    return platformService.watchVPNStatus();
  }

  @override
  Future<Either<Failure, Unit>> isVPNConnected() {
    if (PlatformUtils.isDesktop) {
      return ffiService.isVPNConnected();
    }
    return platformService.isVPNConnected();
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
