// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'website_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SplitTunnelingWebsites)
final splitTunnelingWebsitesProvider = SplitTunnelingWebsitesProvider._();

final class SplitTunnelingWebsitesProvider
    extends $NotifierProvider<SplitTunnelingWebsites, Set<Website>> {
  SplitTunnelingWebsitesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'splitTunnelingWebsitesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$splitTunnelingWebsitesHash();

  @$internal
  @override
  SplitTunnelingWebsites create() => SplitTunnelingWebsites();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<Website> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<Website>>(value),
    );
  }
}

String _$splitTunnelingWebsitesHash() =>
    r'685370d24001266fd3661375ae7be3aa2054a7d8';

abstract class _$SplitTunnelingWebsites extends $Notifier<Set<Website>> {
  Set<Website> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<Website>, Set<Website>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<Website>, Set<Website>>,
              Set<Website>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
