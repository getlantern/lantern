// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appList)
const appListProvider = AppListProvider._();

final class AppListProvider extends $FunctionalProvider<
        AsyncValue<List<AppData>>, List<AppData>, Stream<List<AppData>>>
    with $FutureModifier<List<AppData>>, $StreamProvider<List<AppData>> {
  const AppListProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appListProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appListHash();

  @$internal
  @override
  $StreamProviderElement<List<AppData>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<AppData>> create(Ref ref) {
    return appList(ref);
  }
}

String _$appListHash() => r'628aa554c6181339d04a460920ddfabd6c0232af';
