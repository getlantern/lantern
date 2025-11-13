// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apps_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SplitTunnelingApps)
const splitTunnelingAppsProvider = SplitTunnelingAppsProvider._();

final class SplitTunnelingAppsProvider
    extends $NotifierProvider<SplitTunnelingApps, Set<AppData>> {
  const SplitTunnelingAppsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'splitTunnelingAppsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$splitTunnelingAppsHash();

  @$internal
  @override
  SplitTunnelingApps create() => SplitTunnelingApps();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<AppData> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<AppData>>(value),
    );
  }
}

String _$splitTunnelingAppsHash() =>
    r'17120dba1c32311cd62f64c5233007a2cf152f24';

abstract class _$SplitTunnelingApps extends $Notifier<Set<AppData>> {
  Set<AppData> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Set<AppData>, Set<AppData>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Set<AppData>, Set<AppData>>,
        Set<AppData>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
