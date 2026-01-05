// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_icon_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppIconCache)
const appIconCacheProvider = AppIconCacheProvider._();

final class AppIconCacheProvider
    extends $NotifierProvider<AppIconCache, Map<String, Uint8List>> {
  const AppIconCacheProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appIconCacheProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appIconCacheHash();

  @$internal
  @override
  AppIconCache create() => AppIconCache();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Uint8List> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Uint8List>>(value),
    );
  }
}

String _$appIconCacheHash() => r'8603b6d4e18ec505ddecb593e300d6fdf41cfe70';

abstract class _$AppIconCache extends $Notifier<Map<String, Uint8List>> {
  Map<String, Uint8List> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<Map<String, Uint8List>, Map<String, Uint8List>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Map<String, Uint8List>, Map<String, Uint8List>>,
        Map<String, Uint8List>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(appIconBytes)
const appIconBytesProvider = AppIconBytesFamily._();

final class AppIconBytesProvider extends $FunctionalProvider<
        AsyncValue<Uint8List?>, Uint8List?, FutureOr<Uint8List?>>
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  const AppIconBytesProvider._(
      {required AppIconBytesFamily super.from,
      required AppIconKey super.argument})
      : super(
          retry: null,
          name: r'appIconBytesProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appIconBytesHash();

  @override
  String toString() {
    return r'appIconBytesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as AppIconKey;
    return appIconBytes(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppIconBytesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appIconBytesHash() => r'1fd4828aec90856d3063af353d76f2cc265fa5e4';

final class AppIconBytesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, AppIconKey> {
  const AppIconBytesFamily._()
      : super(
          retry: null,
          name: r'appIconBytesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  AppIconBytesProvider call(
    AppIconKey k,
  ) =>
      AppIconBytesProvider._(argument: k, from: this);

  @override
  String toString() => r'appIconBytesProvider';
}
