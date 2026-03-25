// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lantern_service_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(lanternService)
final lanternServiceProvider = LanternServiceProvider._();

final class LanternServiceProvider
    extends $FunctionalProvider<LanternService, LanternService, LanternService>
    with $Provider<LanternService> {
  LanternServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lanternServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lanternServiceHash();

  @$internal
  @override
  $ProviderElement<LanternService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LanternService create(Ref ref) {
    return lanternService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LanternService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LanternService>(value),
    );
  }
}

String _$lanternServiceHash() => r'3e4ab1e15ccf41a3d913e21f1dd6414a29c8a840';
