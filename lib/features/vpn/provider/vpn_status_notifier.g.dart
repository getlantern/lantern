// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_status_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VPNStatusNotifier)
const vPNStatusProvider = VPNStatusNotifierProvider._();

final class VPNStatusNotifierProvider
    extends $StreamNotifierProvider<VPNStatusNotifier, LanternStatus> {
  const VPNStatusNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'vPNStatusProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$vPNStatusNotifierHash();

  @$internal
  @override
  VPNStatusNotifier create() => VPNStatusNotifier();
}

String _$vPNStatusNotifierHash() => r'6646686e65bcd44969b612a32580dde570328146';

abstract class _$VPNStatusNotifier extends $StreamNotifier<LanternStatus> {
  Stream<LanternStatus> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<LanternStatus>, LanternStatus>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<LanternStatus>, LanternStatus>,
        AsyncValue<LanternStatus>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
