// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostic_log_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiagnosticLogNotifier)
final diagnosticLogProvider = DiagnosticLogNotifierProvider._();

final class DiagnosticLogNotifierProvider
    extends $StreamNotifierProvider<DiagnosticLogNotifier, List<String>> {
  DiagnosticLogNotifierProvider._()
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
    r'3c03a9384ea32162bf86db575a6deca5fa6c5310';

abstract class _$DiagnosticLogNotifier extends $StreamNotifier<List<String>> {
  Stream<List<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<String>>, List<String>>,
              AsyncValue<List<String>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
