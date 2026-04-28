// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'developer_daemon_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Snapshot of dev-mode daemon state plus the IPC calls that mutate it.
/// Auto-disposed so each visit to the developer screen re-fetches fresh
/// state from the native layer.

@ProviderFor(DeveloperDaemonNotifier)
final developerDaemonProvider = DeveloperDaemonNotifierProvider._();

/// Snapshot of dev-mode daemon state plus the IPC calls that mutate it.
/// Auto-disposed so each visit to the developer screen re-fetches fresh
/// state from the native layer.
final class DeveloperDaemonNotifierProvider
    extends $NotifierProvider<DeveloperDaemonNotifier, DeveloperDaemonState> {
  /// Snapshot of dev-mode daemon state plus the IPC calls that mutate it.
  /// Auto-disposed so each visit to the developer screen re-fetches fresh
  /// state from the native layer.
  DeveloperDaemonNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'developerDaemonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$developerDaemonNotifierHash();

  @$internal
  @override
  DeveloperDaemonNotifier create() => DeveloperDaemonNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeveloperDaemonState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeveloperDaemonState>(value),
    );
  }
}

String _$developerDaemonNotifierHash() =>
    r'f636033cdbb65e7e1d0054fed1242c6eabacf01d';

/// Snapshot of dev-mode daemon state plus the IPC calls that mutate it.
/// Auto-disposed so each visit to the developer screen re-fetches fresh
/// state from the native layer.

abstract class _$DeveloperDaemonNotifier
    extends $Notifier<DeveloperDaemonState> {
  DeveloperDaemonState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DeveloperDaemonState, DeveloperDaemonState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DeveloperDaemonState, DeveloperDaemonState>,
              DeveloperDaemonState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
