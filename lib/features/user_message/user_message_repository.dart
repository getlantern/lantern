import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// The narrow Flutter-facing boundary for Radiance's durable message state.
/// Campaign copy deliberately never enters logs or provider diagnostics.
abstract interface class UserMessageRepository {
  Stream<void> get messageAvailable;

  Future<UserMessage?> current();

  Future<void> refresh();

  Future<void> acknowledge(String displayId);
}

class LanternUserMessageRepository implements UserMessageRepository {
  LanternUserMessageRepository(this._service);

  final LanternCoreService _service;

  @override
  Stream<void> get messageAvailable => _service
      .watchAppEvents()
      .where((event) => event.eventType == AppEvent.userMessageAvailable)
      .map((_) {});

  @override
  Future<UserMessage?> current() async {
    return _unwrap(await _service.currentUserMessage());
  }

  @override
  Future<void> refresh() async {
    _unwrap(await _service.refreshUserMessages());
  }

  @override
  Future<void> acknowledge(String displayId) async {
    _unwrap(await _service.acknowledgeUserMessage(displayId));
  }

  T _unwrap<T>(Either<Failure, T> result) {
    return result.fold(
      (_) => throw const UserMessageRepositoryException(),
      (value) => value,
    );
  }
}

class UserMessageRepositoryException implements Exception {
  const UserMessageRepositoryException();
}

final userMessageRepositoryProvider = Provider<UserMessageRepository>((ref) {
  return LanternUserMessageRepository(ref.watch(lanternServiceProvider));
});
