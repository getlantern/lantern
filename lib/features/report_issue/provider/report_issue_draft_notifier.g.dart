// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_issue_draft_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReportIssueDraft)
final reportIssueDraftProvider = ReportIssueDraftProvider._();

final class ReportIssueDraftProvider
    extends $NotifierProvider<ReportIssueDraft, ReportIssueDraftState> {
  ReportIssueDraftProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportIssueDraftProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportIssueDraftHash();

  @$internal
  @override
  ReportIssueDraft create() => ReportIssueDraft();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportIssueDraftState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportIssueDraftState>(value),
    );
  }
}

String _$reportIssueDraftHash() => r'349841e1f2b28b19d05424f234b033fcd702a071';

abstract class _$ReportIssueDraft extends $Notifier<ReportIssueDraftState> {
  ReportIssueDraftState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ReportIssueDraftState, ReportIssueDraftState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReportIssueDraftState, ReportIssueDraftState>,
              ReportIssueDraftState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
