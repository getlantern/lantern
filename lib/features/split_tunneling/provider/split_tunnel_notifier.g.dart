// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_tunnel_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SplitTunnel)
final splitTunnelProvider = SplitTunnelProvider._();

final class SplitTunnelProvider
    extends $AsyncNotifierProvider<SplitTunnel, SplitTunnelState> {
  SplitTunnelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'splitTunnelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$splitTunnelHash();

  @$internal
  @override
  SplitTunnel create() => SplitTunnel();
}

String _$splitTunnelHash() => r'71eeceb50ad7386561abf7735eafb0a812240925';

abstract class _$SplitTunnel extends $AsyncNotifier<SplitTunnelState> {
  FutureOr<SplitTunnelState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SplitTunnelState>, SplitTunnelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SplitTunnelState>, SplitTunnelState>,
              AsyncValue<SplitTunnelState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
