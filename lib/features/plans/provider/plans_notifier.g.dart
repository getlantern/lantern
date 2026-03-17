// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plans_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlansNotifier)
final plansProvider = PlansNotifierProvider._();

final class PlansNotifierProvider
    extends $AsyncNotifierProvider<PlansNotifier, PlansData> {
  PlansNotifierProvider._()
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

String _$plansNotifierHash() => r'e1e0b9efe2723c8f501c487561a811af87fd7780';

abstract class _$PlansNotifier extends $AsyncNotifier<PlansData> {
  FutureOr<PlansData> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PlansData>, PlansData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PlansData>, PlansData>,
              AsyncValue<PlansData>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
