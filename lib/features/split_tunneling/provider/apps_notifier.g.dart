// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apps_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SplitTunnelingApps)
final splitTunnelingAppsProvider = SplitTunnelingAppsProvider._();

final class SplitTunnelingAppsProvider
    extends $AsyncNotifierProvider<SplitTunnelingApps, Set<AppData>> {
  SplitTunnelingAppsProvider._()
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
}

String _$splitTunnelingAppsHash() =>
    r'1ac6edd52bfdfd089e6c5e557699f8170e3dc00a';

abstract class _$SplitTunnelingApps extends $AsyncNotifier<Set<AppData>> {
  FutureOr<Set<AppData>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<AppData>>, Set<AppData>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<AppData>>, Set<AppData>>,
              AsyncValue<Set<AppData>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
