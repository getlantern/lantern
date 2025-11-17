// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VpnNotifier)
const vpnProvider = VpnNotifierProvider._();

final class VpnNotifierProvider
    extends $NotifierProvider<VpnNotifier, VPNStatus> {
  const VpnNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'vpnProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$vpnNotifierHash();

  @$internal
  @override
  VpnNotifier create() => VpnNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VPNStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VPNStatus>(value),
    );
  }
}

String _$vpnNotifierHash() => r'b40feccc8c6d14e95028e75fd5d85eade062de53';

abstract class _$VpnNotifier extends $Notifier<VPNStatus> {
  VPNStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<VPNStatus, VPNStatus>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<VPNStatus, VPNStatus>, VPNStatus, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
