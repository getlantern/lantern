import 'package:lantern/core/models/plan_data.dart';

/// The kind of code applied via the referral-attach V2 endpoint.
///
/// - [affiliate] applies a discount to the plans (strikethrough pricing UI).
/// - [referral] keeps the existing per-plan bonus message UI.
enum ReferralType {
  referral,
  affiliate;

  static ReferralType fromString(String? value) =>
      value == 'referral' ? ReferralType.referral : ReferralType.affiliate;
}

class ReferralAttachV2Response {
  final PlansData plansData;
  final String code;
  final int discountPct;
  final ReferralType type;

  ReferralAttachV2Response({
    required this.plansData,
    required this.code,
    required this.discountPct,
    required this.type,
  });

  bool get isAffiliate => type == ReferralType.affiliate;

  factory ReferralAttachV2Response.fromJson(Map<String, dynamic> json) =>
      ReferralAttachV2Response(
        plansData: PlansData.fromJson(json)..sortPlansAndProviders(),
        code: json["code"] ?? '',
        discountPct: json["discountPct"] ?? 0,
        type: ReferralType.fromString(json["type"]),
      );

  Map<String, dynamic> toJson() => {
    ...plansData.toJson(),
    "code": code,
    "discountPct": discountPct,
    "type": type.name,
  };
}
