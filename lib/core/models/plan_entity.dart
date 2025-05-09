import 'package:objectbox/objectbox.dart';

@Entity()
class PlansDataEntity {
  @Id()
  int id = 0;
  final ToOne<ProvidersEntity> providers = ToOne<ProvidersEntity>();
  final ToMany<PlanEntity> plans = ToMany<PlanEntity>();
  String iconsJson;

  PlansDataEntity({required this.iconsJson});
}

@Entity()
class PlanEntity {
  @Id()
  int id = 0;
  String planId;
  String description;
  int usdPrice;
  String priceJson;
  String expectedMonthlyPriceJson;
  bool? bestValue;

  PlanEntity({
    required this.planId,
    required this.description,
    required this.usdPrice,
    required this.priceJson,
    required this.expectedMonthlyPriceJson,
    this.bestValue,
  });
}

@Entity()
class ProvidersEntity {
  @Id()
  int id = 0;

  String androidJson;
  String desktopJson;

  ProvidersEntity({
    required this.androidJson,
    required this.desktopJson,
  });
}
