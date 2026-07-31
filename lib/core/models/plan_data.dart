import 'package:lantern/core/common/common.dart';

class PlansData {
  Providers providers;
  List<Plan> plans;

  PlansData({required this.providers, required this.plans});

  /// The payment methods offered on the current platform. Matches the
  /// selection in ChoosePaymentMethod: only Android uses the android list;
  /// iOS pays via IAP and falls back to the desktop list like everyone else.
  List<Android> get platformProviders =>
      PlatformUtils.isAndroid ? providers.android : providers.desktop;

  /// Sorts plans (best-value first, then by descending price) and orders the
  /// platform's payment providers so subscription-capable ones come first.
  /// Applied after fetching/attaching plans (including referral V2).
  void sortPlansAndProviders() {
    plans.sort((a, b) {
      if (a.bestValue != b.bestValue) {
        return a.bestValue ? -1 : 1;
      }
      // Then: sort by usdPrice descending
      return b.usdPrice.compareTo(a.usdPrice);
    });

    platformProviders.sort(
      (a, b) =>
          (b.providers.supportSubscription ? 1 : 0) -
          (a.providers.supportSubscription ? 1 : 0),
    );
  }

  /// Publishable key advertised by the Stripe provider for this platform,
  /// or null when Stripe isn't offered or no key was sent.
  String? get stripePubKey {
    for (final method in platformProviders) {
      if (method.providers.name == 'stripe') {
        return method.providers.data.pubKey;
      }
    }
    return null;
  }

  factory PlansData.fromJson(Map<String, dynamic> json) => PlansData(
    providers: Providers.fromJson(json["providers"]),
    plans: List<Plan>.from(json["plans"].map((x) => Plan.fromJson(x))),
  );

  PlansData copyWith({
    Providers? providers,
    List<Plan>? plans,
    Map<String, List<String>>? icons,
  }) {
    return PlansData(
      providers: providers ?? this.providers,
      plans: plans ?? this.plans,
    );
  }

  Map<String, dynamic> toJson() => {
    "providers": providers.toJson(),
    "plans": List<dynamic>.from(plans.map((x) => x.toJson())),
  };
}

class Plan {
  String id;
  String description;
  int usdPrice;
  Map<String, dynamic> price;
  Map<String, dynamic> expectedMonthlyPrice;
  bool bestValue;

  // Original (pre-discount) prices. Only present when a discount (affiliate
  // code) is applied; null otherwise.
  int? originalUsdPrice;
  int? originalUsdPrice1Y;
  int? originalUsdPrice2Y;
  Map<String, dynamic>? originalPrice;
  Map<String, dynamic>? originalExpectedMonthlyPrice;

  Plan({
    required this.id,
    required this.description,
    required this.usdPrice,
    required this.price,
    required this.expectedMonthlyPrice,
    this.bestValue = false,
    this.originalUsdPrice,
    this.originalUsdPrice1Y,
    this.originalUsdPrice2Y,
    this.originalPrice,
    this.originalExpectedMonthlyPrice,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: json["id"],
    description: json["description"],
    usdPrice: json["usdPrice"],
    price: json["price"],
    expectedMonthlyPrice: json["expectedMonthlyPrice"],
    bestValue: json["bestValue"] ?? false,
    originalUsdPrice: json["originalUsdPrice"],
    originalUsdPrice1Y: json["originalUsdPrice1Y"],
    originalUsdPrice2Y: json["originalUsdPrice2Y"],
    originalPrice: json["originalPrice"] == null
        ? null
        : Map<String, dynamic>.from(json["originalPrice"]),
    originalExpectedMonthlyPrice: json["originalExpectedMonthlyPrice"] == null
        ? null
        : Map<String, dynamic>.from(json["originalExpectedMonthlyPrice"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "description": description,
    "usdPrice": usdPrice,
    "price": price,
    "expectedMonthlyPrice": expectedMonthlyPrice,
    "bestValue": bestValue,
    "originalUsdPrice": originalUsdPrice,
    "originalUsdPrice1Y": originalUsdPrice1Y,
    "originalUsdPrice2Y": originalUsdPrice2Y,
    "originalPrice": originalPrice,
    "originalExpectedMonthlyPrice": originalExpectedMonthlyPrice,
  };
}

class Providers {
  List<Android> android;
  List<Android> desktop;

  Providers({required this.android, required this.desktop});

  factory Providers.fromJson(Map<String, dynamic> json) => Providers(
    android: List<Android>.from(
      json["android"].map((x) => Android.fromJson(x)),
    ),
    desktop: List<Android>.from(
      json["desktop"].map((x) => Android.fromJson(x)),
    ),
  );

  Map<String, dynamic> toJson() => {
    "android": List<dynamic>.from(android.map((x) => x.toJson())),
    "desktop": List<dynamic>.from(desktop.map((x) => x.toJson())),
  };
}

class Android {
  String method;
  Provider providers;

  Android({required this.method, required this.providers});

  factory Android.fromJson(Map<String, dynamic> json) => Android(
    method: json["method"],
    providers: Provider.fromJson(json["provider"]),
  );

  Map<String, dynamic> toJson() => {
    "method": method,
    "provider": providers.toJson(),
  };
}

class Provider {
  String name;
  ProviderData data;
  List<String> icons;
  bool supportSubscription;

  Provider({
    required this.name,
    required this.icons,
    required this.supportSubscription,
    ProviderData? data,
  }) : data = data ?? ProviderData();

  factory Provider.fromJson(Map<String, dynamic> json) => Provider(
    name: json["name"],
    data: ProviderData.fromJson(json["data"]),
    icons: List<String>.from(json["icons"].map((x) => x)),
    supportSubscription: json["supportsSubscription"] ?? false,
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "data": data.toJson(),
    "icons": List<dynamic>.from(icons.map((x) => x)),
    "supportsSubscription": supportSubscription,
  };
}

/// Provider-specific payload. Its keys vary by provider (Stripe sends
/// `pubKey`, shepherd sends nothing), so the raw map is kept alongside the
/// typed accessors for keys the app understands.
class ProviderData {
  final Map<String, dynamic> raw;

  ProviderData({this.raw = const {}});

  /// Stripe publishable key for this provider, or null if absent/empty.
  String? get pubKey {
    final value = raw['pubKey'];
    return value is String && value.isNotEmpty ? value : null;
  }

  factory ProviderData.fromJson(dynamic json) => ProviderData(
    raw: json is Map ? Map<String, dynamic>.from(json) : const {},
  );

  Map<String, dynamic> toJson() => raw;
}
