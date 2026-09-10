// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_cap_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DataCapInfoNotifier)
final dataCapInfoProvider = DataCapInfoNotifierProvider._();

final class DataCapInfoNotifierProvider
    extends $AsyncNotifierProvider<DataCapInfoNotifier, DataCapUsageResponse> {
  DataCapInfoNotifierProvider._()
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
    r'90aaeb34d1801962f3a400834364028fb0f15cd3';

abstract class _$DataCapInfoNotifier
    extends $AsyncNotifier<DataCapUsageResponse> {
  FutureOr<DataCapUsageResponse> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<DataCapUsageResponse>, DataCapUsageResponse>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DataCapUsageResponse>,
                DataCapUsageResponse
              >,
              AsyncValue<DataCapUsageResponse>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
