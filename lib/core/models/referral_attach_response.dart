import 'package:lantern/core/models/plan_data.dart';

/// Response returned by the referral-attach V2 endpoint. In addition to
/// attaching the referral code it returns the resulting discounted plans,
/// payment providers, and the applied discount percentage.
class ReferralAttachV2Response {
  final Providers? providers;
  final List<Plan> plans;
  final String code;
  final int discountPct;

  ReferralAttachV2Response({
    required this.providers,
    required this.plans,
    required this.code,
    required this.discountPct,
  });

  factory ReferralAttachV2Response.fromJson(Map<String, dynamic> json) =>
      ReferralAttachV2Response(
        providers: json["providers"] == null
            ? null
            : Providers.fromJson(json["providers"]),
        plans: json["plans"] == null
            ? <Plan>[]
            : List<Plan>.from(json["plans"].map((x) => Plan.fromJson(x))),
        code: json["code"] ?? '',
        discountPct: json["discountPct"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "providers": providers?.toJson(),
        "plans": List<dynamic>.from(plans.map((x) => x.toJson())),
        "code": code,
        "discountPct": discountPct,
      };
}
