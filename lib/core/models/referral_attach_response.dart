import 'package:lantern/core/models/plan_data.dart';

/// The kind of code applied via the referral-attach V2 endpoint.
class ReferralType {
  static const affiliate = 'affiliate';
  static const referral = 'referral';
}

class ReferralAttachV2Response {
  final PlansData plansData;
  final String code;
  final int discountPct;

  /// Either [ReferralType.affiliate] or [ReferralType.referral].
  final String type;

  ReferralAttachV2Response({
    required this.plansData,
    required this.code,
    required this.discountPct,
    required this.type,
  });

  /// Affiliate codes apply a discount to the plans (strikethrough pricing UI);
  /// referral codes keep the existing per-plan bonus message UI.
  bool get isAffiliate => type == ReferralType.affiliate;

  factory ReferralAttachV2Response.fromJson(Map<String, dynamic> json) =>
      ReferralAttachV2Response(
        plansData: PlansData.fromJson(json)..sortPlansAndProviders(),
        code: json["code"] ?? '',
        discountPct: json["discountPct"] ?? 0,
        type: json["type"] ?? ReferralType.affiliate,
      );

  Map<String, dynamic> toJson() => {
    ...plansData.toJson(),
    "code": code,
    "discountPct": discountPct,
    "type": type,
  };
}
