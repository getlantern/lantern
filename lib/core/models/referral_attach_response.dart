import 'package:lantern/core/models/plan_data.dart';

/// The kind of code applied via the referral-attach V2 endpoint.
///
/// - [none] nothing applied (the notifier's default/null state).
/// - [affiliate] applies a discount to the plans (strikethrough pricing UI).
/// - [referral] keeps the existing per-plan bonus message UI.
enum ReferralType {
  none,
  referral,
  affiliate;

  static ReferralType fromString(String? value) => switch (value) {
    'referral' => ReferralType.referral,
    'affiliate' => ReferralType.affiliate,
    _ => ReferralType.none,
  };
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

/// Null-safe accessors for the referral notifier state
/// (`ReferralAttachV2Response?`). Lets callers branch on [type] and read
/// [code] / [discountPct] directly, without repeated `!= null` checks — a
/// null state simply reports [ReferralType.none], empty code, and 0 discount.
extension ReferralStateX on ReferralAttachV2Response? {
  ReferralType get type => this?.type ?? ReferralType.none;
  bool get isApplied => this != null;
  bool get isAffiliate => type == ReferralType.affiliate;
  bool get isReferral => type == ReferralType.referral;
  String get code => this?.code ?? '';
  int get discountPct => this?.discountPct ?? 0;
}
