import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/user_message/user_message_repository.dart';
import 'package:lantern/lantern/lantern_core_service.dart';

import 'user_message_test_fakes.dart';

class _FakeCore implements LanternCoreService {
  final events = StreamController<AppEvent>.broadcast();
  Either<Failure, UserMessage?> currentResult = right(null);
  Either<Failure, Unit> refreshResult = right(unit);
  Either<Failure, Unit> acknowledgeResult = right(unit);
  final acknowledged = <String>[];
  final activity = <bool>[];

  @override
  Stream<AppEvent> watchAppEvents() => events.stream;

  @override
  Future<Either<Failure, UserMessage?>> currentUserMessage() async =>
      currentResult;

  @override
  Future<Either<Failure, Unit>> refreshUserMessages() async => refreshResult;

  @override
  Future<Either<Failure, Unit>> acknowledgeUserMessage(String displayId) async {
    acknowledged.add(displayId);
    return acknowledgeResult;
  }

  @override
  Future<Either<Failure, Unit>> setUserMessageActivity(bool active) async {
    activity.add(active);
    return right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'adapts current, refresh, acknowledge, and availability events',
    () async {
      final core = _FakeCore();
      addTearDown(core.events.close);
      final message = testUserMessage();
      core.currentResult = right(message);
      final repository = LanternUserMessageRepository(core);

      final available = expectLater(repository.messageAvailable, emits(null));
      core.events.add(AppEvent(eventType: 'config', message: 'ignored'));
      core.events.add(
        AppEvent(eventType: AppEvent.userMessageAvailable, message: ''),
      );

      expect(await repository.current(), same(message));
      await repository.refresh();
      await repository.acknowledge(message.displayId);
      await repository.setActive(false);
      expect(core.acknowledged, [message.displayId]);
      expect(core.activity, [false]);
      await available;
    },
  );

  test('converts bridge failures without retaining their content', () async {
    final core = _FakeCore();
    addTearDown(core.events.close);
    core.currentResult = left(
      Failure(
        error: 'localized campaign copy must not escape',
        localizedErrorMessage: 'localized campaign copy must not escape',
      ),
    );
    final repository = LanternUserMessageRepository(core);

    await expectLater(
      repository.current(),
      throwsA(isA<UserMessageRepositoryException>()),
    );
  });
}
