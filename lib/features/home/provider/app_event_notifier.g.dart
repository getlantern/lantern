// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_event_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Listens for application-wide events and triggers corresponding actions.
/// This can be used for all listening to events that go sends and handling them
/// in one place.

@ProviderFor(AppEventNotifier)
const appEventProvider = AppEventNotifierProvider._();

/// Listens for application-wide events and triggers corresponding actions.
/// This can be used for all listening to events that go sends and handling them
/// in one place.
final class AppEventNotifierProvider
    extends $AsyncNotifierProvider<AppEventNotifier, void> {
  /// Listens for application-wide events and triggers corresponding actions.
  /// This can be used for all listening to events that go sends and handling them
  /// in one place.
  const AppEventNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appEventProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appEventNotifierHash();

  @$internal
  @override
  AppEventNotifier create() => AppEventNotifier();
}

String _$appEventNotifierHash() => r'8f75119554318f8215c5025ebd70d8bc5756dc06';

/// Listens for application-wide events and triggers corresponding actions.
/// This can be used for all listening to events that go sends and handling them
/// in one place.

abstract class _$AppEventNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<void>, void>,
        AsyncValue<void>,
        Object?,
        Object?>;
    element.handleValue(ref, null);
  }
}
