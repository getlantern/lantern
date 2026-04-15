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
    extends $AsyncNotifierProvider<SplitTunnelingWebsites, Set<Website>> {
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
}

String _$splitTunnelingWebsitesHash() =>
    r'9d2203716964f9fdcec48707f8993767dfa61161';

abstract class _$SplitTunnelingWebsites extends $AsyncNotifier<Set<Website>> {
  FutureOr<Set<Website>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<Website>>, Set<Website>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<Website>>, Set<Website>>,
              AsyncValue<Set<Website>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
