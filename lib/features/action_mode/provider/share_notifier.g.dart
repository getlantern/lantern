// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives connection sharing in both modes: Unbounded (broflake/WebRTC) and
/// the samizdat-over-UPnP "Share My Connection" (SmC) mode.
///
/// Turning sharing on collects consent, then picks the mode from the network:
/// a manual port or a working UPnP gateway means SmC, anything else means
/// Unbounded. SmC start failures fall back to Unbounded transparently.

@ProviderFor(ShareNotifier)
final shareProvider = ShareNotifierProvider._();

/// Drives connection sharing in both modes: Unbounded (broflake/WebRTC) and
/// the samizdat-over-UPnP "Share My Connection" (SmC) mode.
///
/// Turning sharing on collects consent, then picks the mode from the network:
/// a manual port or a working UPnP gateway means SmC, anything else means
/// Unbounded. SmC start failures fall back to Unbounded transparently.
final class ShareNotifierProvider
    extends $NotifierProvider<ShareNotifier, ShareState> {
  /// Drives connection sharing in both modes: Unbounded (broflake/WebRTC) and
  /// the samizdat-over-UPnP "Share My Connection" (SmC) mode.
  ///
  /// Turning sharing on collects consent, then picks the mode from the network:
  /// a manual port or a working UPnP gateway means SmC, anything else means
  /// Unbounded. SmC start failures fall back to Unbounded transparently.
  ShareNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareNotifierHash();

  @$internal
  @override
  ShareNotifier create() => ShareNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareState>(value),
    );
  }
}

String _$shareNotifierHash() => r'1946982d6be36f4e8b23f0c25c2e9cdca1d6608a';

/// Drives connection sharing in both modes: Unbounded (broflake/WebRTC) and
/// the samizdat-over-UPnP "Share My Connection" (SmC) mode.
///
/// Turning sharing on collects consent, then picks the mode from the network:
/// a manual port or a working UPnP gateway means SmC, anything else means
/// Unbounded. SmC start failures fall back to Unbounded transparently.

abstract class _$ShareNotifier extends $Notifier<ShareState> {
  ShareState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ShareState, ShareState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ShareState, ShareState>,
              ShareState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
