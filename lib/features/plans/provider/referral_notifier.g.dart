// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referral_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReferralNotifier)
final referralProvider = ReferralNotifierProvider._();

final class ReferralNotifierProvider
    extends $NotifierProvider<ReferralNotifier, ReferralAttachV2Response?> {
  ReferralNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referralProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referralNotifierHash();

  @$internal
  @override
  ReferralNotifier create() => ReferralNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReferralAttachV2Response? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReferralAttachV2Response?>(value),
    );
  }
}

String _$referralNotifierHash() => r'e5def696bebc6776e566c6f91c98475970497dcc';

abstract class _$ReferralNotifier extends $Notifier<ReferralAttachV2Response?> {
  ReferralAttachV2Response? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<ReferralAttachV2Response?, ReferralAttachV2Response?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReferralAttachV2Response?, ReferralAttachV2Response?>,
              ReferralAttachV2Response?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
