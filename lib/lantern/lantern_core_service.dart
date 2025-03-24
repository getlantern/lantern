import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';

/// LanternCoreService has all method that interact with lantern-core services
abstract class LanternCoreService{
  Future<Either<String,Unit>> setupRadiance();
  Future<Either<Failure,Unit>> startVPN();

  void stopVPN();
}