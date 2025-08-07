import 'dart:convert';

import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/plan_entity.dart';

extension PlansDataMapper on PlansData {
  PlansDataEntity toEntity() {
    final entity = PlansDataEntity();
    entity.plans.addAll(plans.map((e) => e.toEntity()));
    entity.providers.target = providers.toEntity();
    return entity;
  }
}

extension PlanEntityMapper on Plan {
  PlanEntity toEntity() {
    return PlanEntity(
      planId: id,
      description: description,
      usdPrice: usdPrice,
      priceJson: jsonEncode(price),
      expectedMonthlyPriceJson: jsonEncode(expectedMonthlyPrice),
      bestValue: bestValue,
    );
  }
}

extension ProvidersMapper on Providers {
  ProvidersEntity toEntity() {
    return ProvidersEntity(
      androidJson: jsonEncode(android.map((e) => e.toJson()).toList()),
      desktopJson: jsonEncode(desktop.map((e) => e.toJson()).toList()),
    );
  }
}

extension ToPlanData on PlansDataEntity {
  PlansData toPlanData() => PlansData(
        providers: providers.target!.toProvider(),
        plans: plans.map((e) => e.toPlan()).toList(),
      );
}

extension PlanData on PlanEntity {
  Plan toPlan() => Plan(
        id: planId,
        description: description,
        usdPrice: usdPrice,
        price: jsonDecode(priceJson),
        expectedMonthlyPrice: jsonDecode(expectedMonthlyPriceJson),
        bestValue: bestValue ?? false,
      );
}

extension ProvidersEntityMapper on ProvidersEntity {
  Providers toProvider() => Providers(
        android: List<Android>.from(
            jsonDecode(androidJson).map((x) => Android.fromJson(x))),
        desktop: List<Android>.from(
            jsonDecode(desktopJson).map((x) => Android.fromJson(x))),
      );
}
