// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plans_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlansNotifier)
const plansProvider = PlansNotifierProvider._();

final class PlansNotifierProvider
    extends $AsyncNotifierProvider<PlansNotifier, PlansData> {
  const PlansNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'plansProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$plansNotifierHash();

  @$internal
  @override
  PlansNotifier create() => PlansNotifier();
}

String _$plansNotifierHash() => r'74ab42d6f09eb7c8b639751ccc5e8704319dcf99';

abstract class _$PlansNotifier extends $AsyncNotifier<PlansData> {
  FutureOr<PlansData> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<PlansData>, PlansData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PlansData>, PlansData>,
        AsyncValue<PlansData>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
