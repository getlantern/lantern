// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostic_log_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diagnosticLogStream)
const diagnosticLogStreamProvider = DiagnosticLogStreamProvider._();

final class DiagnosticLogStreamProvider extends $FunctionalProvider<
        AsyncValue<List<String>>, List<String>, Stream<List<String>>>
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  const DiagnosticLogStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'diagnosticLogStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$diagnosticLogStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return diagnosticLogStream(ref);
  }
}

String _$diagnosticLogStreamHash() =>
    r'a633ad4b5899238717f8e58305439aba21764742';
