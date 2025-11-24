// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'developer_mode_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeveloperModeNotifier)
const developerModeProvider = DeveloperModeNotifierProvider._();

final class DeveloperModeNotifierProvider
    extends $NotifierProvider<DeveloperModeNotifier, DeveloperModeEntity> {
  const DeveloperModeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'developerModeProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$developerModeNotifierHash();

  @$internal
  @override
  DeveloperModeNotifier create() => DeveloperModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeveloperModeEntity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeveloperModeEntity>(value),
    );
  }
}

String _$developerModeNotifierHash() =>
    r'fecb33fb19646edb2cc61644182910e3a7a33f0d';

abstract class _$DeveloperModeNotifier extends $Notifier<DeveloperModeEntity> {
  DeveloperModeEntity build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<DeveloperModeEntity, DeveloperModeEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DeveloperModeEntity, DeveloperModeEntity>,
        DeveloperModeEntity,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
