import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';

/// LanternCoreService has all method that interact with lantern-core services
abstract class LanternCoreService {
  Future<void> init();

  Future<Either<Failure, Unit>> isVPNConnected();

  Future<Either<Failure, String>> startVPN();

  Future<Either<Failure, String>> stopVPN();

  Stream<LanternStatus> watchVPNStatus();
}
