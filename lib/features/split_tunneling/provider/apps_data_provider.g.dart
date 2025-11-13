// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apps_data_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appsData)
const appsDataProvider = AppsDataProvider._();

final class AppsDataProvider extends $FunctionalProvider<
        AsyncValue<List<AppData>>, List<AppData>, Stream<List<AppData>>>
    with $FutureModifier<List<AppData>>, $StreamProvider<List<AppData>> {
  const AppsDataProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appsDataProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appsDataHash();

  @$internal
  @override
  $StreamProviderElement<List<AppData>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<AppData>> create(Ref ref) {
    return appsData(ref);
  }
}

String _$appsDataHash() => r'e5b42cf4dd18e6c822489c85b358cbbccbad1f71';
