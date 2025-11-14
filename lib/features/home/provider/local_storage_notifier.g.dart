// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_storage_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LocalStorageNotifier)
const localStorageProvider = LocalStorageNotifierProvider._();

final class LocalStorageNotifierProvider
    extends $NotifierProvider<LocalStorageNotifier, LocalStorageService> {
  const LocalStorageNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'localStorageProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localStorageNotifierHash();

  @$internal
  @override
  LocalStorageNotifier create() => LocalStorageNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalStorageService>(value),
    );
  }
}

String _$localStorageNotifierHash() =>
    r'50ffb0a50e3e433670550ac01a2c9152c85e3e29';

abstract class _$LocalStorageNotifier extends $Notifier<LocalStorageService> {
  LocalStorageService build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<LocalStorageService, LocalStorageService>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<LocalStorageService, LocalStorageService>,
        LocalStorageService,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
