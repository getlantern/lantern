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
    extends $NotifierProvider<DeveloperModeNotifier, DeveloperMode> {
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
  Override overrideWithValue(DeveloperMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeveloperMode>(value),
    );
  }
}

String _$developerModeNotifierHash() =>
    r'32f2c61108de9fe0e78afecaad4aa4bcc2299e94';

abstract class _$DeveloperModeNotifier extends $Notifier<DeveloperMode> {
  DeveloperMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<DeveloperMode, DeveloperMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DeveloperMode, DeveloperMode>,
        DeveloperMode,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
