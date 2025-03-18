/// LanternCoreService has all method that interact with lantern-core services
abstract class LanternCoreService{
  void setupRadiance();
  void startVPN();

  void stopVPN();
}