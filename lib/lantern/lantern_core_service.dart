import 'package:fpdart/fpdart.dart';

/// LanternCoreService has all method that interact with lantern-core services
abstract class LanternCoreService{
  Future<Either<String,Unit>> setupRadiance();
  void startVPN();

  void stopVPN();
}