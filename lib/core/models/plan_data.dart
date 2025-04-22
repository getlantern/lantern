import 'dart:convert';

class PlansData {
  Providers providers;
  List<Plan> plans;
  Map<String, List<String>> icons;

  PlansData({
    required this.providers,
    required this.plans,
    required this.icons,
  });

  factory PlansData.fromJson(Map<String, dynamic> json) => PlansData(
        providers: Providers.fromJson(json["providers"]),
        plans: List<Plan>.from(json["plans"].map((x) => Plan.fromJson(x))),
        icons: (json["icons"] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      );

  Map<String, dynamic> toJson() => {
        "providers": providers.toJson(),
        "plans": List<dynamic>.from(plans.map((x) => x.toJson())),
      };
}


class Plan {
  String id;
  String description;
  int usdPrice;
  String price;
  String expectedMonthlyPrice;
  bool? bestValue;

  Plan({
    required this.id,
    required this.description,
    required this.usdPrice,
    required this.price,
    required this.expectedMonthlyPrice,
    this.bestValue,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json["id"],
        description: json["description"],
        usdPrice: json["usdPrice"],
        price: jsonEncode(json["price"]),
        expectedMonthlyPrice: jsonEncode(json["expectedMonthlyPrice"]),
        bestValue: json["bestValue"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "description": description,
        "usdPrice": usdPrice,
        "price": price,
        "expectedMonthlyPrice": expectedMonthlyPrice,
        "bestValue": bestValue,
      };
}

class Providers {
  List<Android> android;
  List<Android> desktop;

  Providers({
    required this.android,
    required this.desktop,
  });

  factory Providers.fromJson(Map<String, dynamic> json) => Providers(
        android:
            List<Android>.from(json["android"].map((x) => Android.fromJson(x))),
        desktop:
            List<Android>.from(json["desktop"].map((x) => Android.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "android": List<dynamic>.from(android.map((x) => x.toJson())),
        "desktop": List<dynamic>.from(desktop.map((x) => x.toJson())),
      };
}

class Android {
  String method;
  List<Provider> providers;

  Android({
    required this.method,
    required this.providers,
  });

  factory Android.fromJson(Map<String, dynamic> json) => Android(
        method: json["method"],
        providers: List<Provider>.from(
            json["providers"].map((x) => Provider.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "method": method,
        "providers": List<dynamic>.from(providers.map((x) => x.toJson())),
      };
}

class Provider {
  String name;
  Map<String, dynamic>? data;

  Provider({
    required this.name,
    this.data,
  });

  factory Provider.fromJson(Map<String, dynamic> json) => Provider(
        name: json["name"],
        data: json["data"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
      };
}
