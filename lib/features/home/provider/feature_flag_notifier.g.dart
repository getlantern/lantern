// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flag_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeatureFlagNotifier)
const featureFlagProvider = FeatureFlagNotifierProvider._();

final class FeatureFlagNotifierProvider
    extends $NotifierProvider<FeatureFlagNotifier, Map<String, dynamic>> {
  const FeatureFlagNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'featureFlagProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$featureFlagNotifierHash();

  @$internal
  @override
  FeatureFlagNotifier create() => FeatureFlagNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, dynamic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, dynamic>>(value),
    );
  }
}

String _$featureFlagNotifierHash() =>
    r'fb9b17b6d71951364cbbbb09c1633e70dca46f24';

abstract class _$FeatureFlagNotifier extends $Notifier<Map<String, dynamic>> {
  Map<String, dynamic> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, dynamic>, Map<String, dynamic>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Map<String, dynamic>, Map<String, dynamic>>,
        Map<String, dynamic>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
