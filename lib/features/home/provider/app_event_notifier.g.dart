// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_event_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appEventNotifierHash() => r'851c13e9d99662f57373454b3dab43e41da4d379';

/// Listens for application-wide events and triggers corresponding actions.
/// This can be used for all listening to events that go sends and handling them
/// in one place.
///
/// Copied from [AppEventNotifier].
@ProviderFor(AppEventNotifier)
final appEventNotifierProvider =
    AsyncNotifierProvider<AppEventNotifier, void>.internal(
  AppEventNotifier.new,
  name: r'appEventNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appEventNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppEventNotifier = AsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
