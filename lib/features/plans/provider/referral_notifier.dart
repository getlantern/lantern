import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/referral_attach_response.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'referral_notifier.g.dart';

@Riverpod(keepAlive: true)
class ReferralNotifier extends _$ReferralNotifier {
  @override
  bool build() {
    return false;
  }

  Future<Either<Failure, String>> applyReferralCode(String code) async {
    final result =
        await ref.read(lanternServiceProvider).attachReferralCode(code);
    if (result.isRight()) {
      state = true;
    }
    return result;
  }

  /// Applies a referral code via the V2 endpoint, returning the resulting
  /// discounted plans, providers and discount percentage.
  Future<Either<Failure, ReferralAttachV2Response>> applyReferralCodeV2(
    String code,
  ) async {
    final result =
        await ref.read(lanternServiceProvider).attachReferralCodeV2(code);
    if (result.isRight()) {
      state = true;
    }
    return result;
  }

  void resetReferral() {
    state = false;
  }
}
