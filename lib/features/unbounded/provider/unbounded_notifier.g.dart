// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unbounded_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UnboundedNotifier)
const unboundedProvider = UnboundedNotifierProvider._();

final class UnboundedNotifierProvider
    extends $NotifierProvider<UnboundedNotifier, UnboundedStats> {
  const UnboundedNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'unboundedProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$unboundedNotifierHash();

  @$internal
  @override
  UnboundedNotifier create() => UnboundedNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UnboundedStats value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UnboundedStats>(value),
    );
  }
}

String _$unboundedNotifierHash() => r'f5d26079a98de84fe0b96f881a0030c28902c067';

abstract class _$UnboundedNotifier extends $Notifier<UnboundedStats> {
  UnboundedStats build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<UnboundedStats, UnboundedStats>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<UnboundedStats, UnboundedStats>,
        UnboundedStats,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
