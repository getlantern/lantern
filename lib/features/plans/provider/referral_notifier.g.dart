// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referral_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReferralNotifier)
const referralProvider = ReferralNotifierProvider._();

final class ReferralNotifierProvider
    extends $NotifierProvider<ReferralNotifier, bool> {
  const ReferralNotifierProvider._()
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
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$referralNotifierHash() => r'6b028ac616c6b663b1e38d2769ca69f063924721';

abstract class _$ReferralNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
