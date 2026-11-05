// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'country_code_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CountryCodeNotifier)
final countryCodeProvider = CountryCodeNotifierProvider._();

final class CountryCodeNotifierProvider
    extends $NotifierProvider<CountryCodeNotifier, String> {
  CountryCodeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countryCodeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countryCodeNotifierHash();

  @$internal
  @override
  CountryCodeNotifier create() => CountryCodeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$countryCodeNotifierHash() =>
    r'6d4e2e5976694966396a758ca782c20d16b3a474';

abstract class _$CountryCodeNotifier extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
