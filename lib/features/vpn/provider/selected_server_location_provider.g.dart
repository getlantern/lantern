// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_server_location_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SelectedServerLocation)
const selectedServerLocationProvider = SelectedServerLocationProvider._();

final class SelectedServerLocationProvider
    extends $AsyncNotifierProvider<SelectedServerLocation, ServerLocation> {
  const SelectedServerLocationProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'selectedServerLocationProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$selectedServerLocationHash();

  @$internal
  @override
  SelectedServerLocation create() => SelectedServerLocation();
}

String _$selectedServerLocationHash() =>
    r'8ab1b8b79e6dfc3b85bec00018bbdc796d2cb148';

abstract class _$SelectedServerLocation extends $AsyncNotifier<ServerLocation> {
  FutureOr<ServerLocation> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<ServerLocation>, ServerLocation>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<ServerLocation>, ServerLocation>,
        AsyncValue<ServerLocation>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
