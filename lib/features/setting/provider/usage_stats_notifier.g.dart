// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage_stats_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The on-device usage stats the Usage stats screen shows. Auto-disposed, so
/// nothing reads them once the screen closes.

@ProviderFor(UsageStatsNotifier)
final usageStatsProvider = UsageStatsNotifierProvider._();

/// The on-device usage stats the Usage stats screen shows. Auto-disposed, so
/// nothing reads them once the screen closes.
final class UsageStatsNotifierProvider
    extends $AsyncNotifierProvider<UsageStatsNotifier, UsageStats> {
  /// The on-device usage stats the Usage stats screen shows. Auto-disposed, so
  /// nothing reads them once the screen closes.
  UsageStatsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageStatsNotifierHash();

  @$internal
  @override
  UsageStatsNotifier create() => UsageStatsNotifier();
}

String _$usageStatsNotifierHash() =>
    r'49fba3d31d21bca422299c8f4ce48c57ec7b0e6a';

/// The on-device usage stats the Usage stats screen shows. Auto-disposed, so
/// nothing reads them once the screen closes.

abstract class _$UsageStatsNotifier extends $AsyncNotifier<UsageStats> {
  FutureOr<UsageStats> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UsageStats>, UsageStats>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UsageStats>, UsageStats>,
              AsyncValue<UsageStats>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
