// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_cap_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DataCapInfoNotifier)
const dataCapInfoProvider = DataCapInfoNotifierProvider._();

final class DataCapInfoNotifierProvider
    extends $AsyncNotifierProvider<DataCapInfoNotifier, DataCapInfo> {
  const DataCapInfoNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dataCapInfoProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dataCapInfoNotifierHash();

  @$internal
  @override
  DataCapInfoNotifier create() => DataCapInfoNotifier();
}

String _$dataCapInfoNotifierHash() =>
    r'1adc99fa5869e3420efeae4c09cabfaf4bc899f8';

abstract class _$DataCapInfoNotifier extends $AsyncNotifier<DataCapInfo> {
  FutureOr<DataCapInfo> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<DataCapInfo>, DataCapInfo>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<DataCapInfo>, DataCapInfo>,
        AsyncValue<DataCapInfo>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
