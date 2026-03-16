// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostic_log_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiagnosticLogNotifier)
const diagnosticLogProvider = DiagnosticLogNotifierProvider._();

final class DiagnosticLogNotifierProvider
    extends $StreamNotifierProvider<DiagnosticLogNotifier, List<String>> {
  const DiagnosticLogNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'diagnosticLogProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$diagnosticLogNotifierHash();

  @$internal
  @override
  DiagnosticLogNotifier create() => DiagnosticLogNotifier();
}

String _$diagnosticLogNotifierHash() =>
    r'3690e816719a11304ba1cfcef1248f5a8d81d0c4';

abstract class _$DiagnosticLogNotifier extends $StreamNotifier<List<String>> {
  Stream<List<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<String>>, List<String>>,
        AsyncValue<List<String>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
