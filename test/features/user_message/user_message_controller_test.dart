import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/features/user_message/user_message_controller.dart';
import 'package:lantern/features/user_message/user_message_repository.dart';

import 'user_message_test_fakes.dart';

void main() {
  late FakeUserMessageRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeUserMessageRepository();
    container = ProviderContainer(
      overrides: [userMessageRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() async {
    container.dispose();
    await repository.dispose();
  });

  test('loads current state at startup and reloads on availability', () async {
    final first = testUserMessage();
    repository.currentMessage = first;
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();

    expect(container.read(userMessageControllerProvider).pending, same(first));
    expect(repository.refreshCalls, 1);
    expect(repository.activity, [true]);

    final second = testUserMessage(displayId: 'campaign-2:generation-1');
    repository.currentMessage = second;
    repository.events.add(null);
    await pumpProviderQueue();

    expect(container.read(userMessageControllerProvider).pending, same(second));
    expect(repository.currentCalls, 2);
  });

  test('claims once and acknowledges only after presentation', () async {
    final message = testUserMessage();
    repository.currentMessage = message;
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();
    final controller = container.read(userMessageControllerProvider.notifier);

    expect(controller.claimForPresentation(DateTime.now()), same(message));
    expect(repository.acknowledged, isEmpty);
    expect(controller.claimForPresentation(DateTime.now()), isNull);

    await controller.markPresented(message.displayId);
    expect(repository.acknowledged, [message.displayId]);
    expect(
      container.read(userMessageControllerProvider).displayedThisSession,
      isTrue,
    );

    repository.currentMessage = testUserMessage(
      displayId: 'campaign-2:generation-1',
    );
    repository.events.add(null);
    await pumpProviderQueue();
    expect(container.read(userMessageControllerProvider).pending, isNull);
  });

  test('drops expired messages before they can be claimed', () async {
    repository.currentMessage = testUserMessage(
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();

    final controller = container.read(userMessageControllerProvider.notifier);
    expect(controller.claimForPresentation(DateTime.now()), isNull);
    expect(container.read(userMessageControllerProvider).pending, isNull);
    expect(repository.acknowledged, isEmpty);
  });

  test(
    'foreground reconciliation pulls current state and requests refresh',
    () async {
      container.read(userMessageControllerProvider);
      await pumpProviderQueue();
      repository.refreshCalls = 0;
      final message = testUserMessage();
      repository.currentMessage = message;

      await container
          .read(userMessageControllerProvider.notifier)
          .onForegrounded();

      expect(
        container.read(userMessageControllerProvider).pending,
        same(message),
      );
      expect(repository.refreshCalls, 1);
      expect(repository.activity.last, isTrue);
    },
  );

  test('pauses polling while backgrounded', () async {
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();

    await container
        .read(userMessageControllerProvider.notifier)
        .onBackgrounded();

    expect(repository.activity, [true, false]);
  });

  test('serializes native lifecycle updates', () async {
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();
    repository.activity.clear();
    final backgroundCompleted = Completer<void>();
    repository.onSetActive = (active) async {
      if (!active) await backgroundCompleted.future;
    };
    final controller = container.read(userMessageControllerProvider.notifier);
    final background = controller.onBackgrounded();
    await pumpProviderQueue();
    final foreground = controller.onForegrounded();
    await pumpProviderQueue();
    expect(repository.activity, [false]);
    backgroundCompleted.complete();
    await Future.wait([background, foreground]);
    expect(repository.activity, [false, true]);
  });

  test(
    'clears queued content while revalidating the current account',
    () async {
      repository.currentMessage = testUserMessage();
      container.read(userMessageControllerProvider);
      await pumpProviderQueue();
      final pendingRead = Completer<UserMessage?>();
      repository.onCurrent = () => pendingRead.future;
      final load = container
          .read(userMessageControllerProvider.notifier)
          .loadCurrent();
      expect(container.read(userMessageControllerProvider).pending, isNull);
      pendingRead.complete(null);
      await load;
      expect(container.read(userMessageControllerProvider).pending, isNull);
    },
  );

  testWidgets('retries acknowledgment without displaying again', (
    tester,
  ) async {
    repository.currentMessage = testUserMessage();
    repository.acknowledgeError = Exception('IPC unavailable');
    container.read(userMessageControllerProvider);
    await tester.pump();
    final controller = container.read(userMessageControllerProvider.notifier);
    final message = controller.claimForPresentation(DateTime.now())!;
    await controller.markPresented(message.displayId);
    expect(repository.acknowledgeCalls, 1);
    expect(controller.claimForPresentation(DateTime.now()), isNull);
    repository.acknowledgeError = null;
    await tester.pump(const Duration(seconds: 1));
    expect(repository.acknowledged, [message.displayId]);
    expect(repository.acknowledgedAccounts, [message.accountId]);
  });

  testWidgets('abandons a retry after switching accounts', (tester) async {
    repository.currentMessage = testUserMessage();
    repository.acknowledgeError = Exception('IPC unavailable');
    container.read(userMessageControllerProvider);
    await tester.pump();
    final controller = container.read(userMessageControllerProvider.notifier);
    final message = controller.claimForPresentation(DateTime.now())!;
    await controller.markPresented(message.displayId);
    repository.currentMessage = testUserMessage(accountId: '67890');
    repository.acknowledgeError = null;
    await tester.pump(const Duration(seconds: 1));
    expect(repository.acknowledgeCalls, 1);
    expect(repository.acknowledged, isEmpty);
  });

  testWidgets('bounds failed acknowledgment attempts', (tester) async {
    repository.currentMessage = testUserMessage();
    repository.acknowledgeError = Exception('IPC unavailable');
    container.read(userMessageControllerProvider);
    await tester.pump();
    final controller = container.read(userMessageControllerProvider.notifier);
    final message = controller.claimForPresentation(DateTime.now())!;
    await controller.markPresented(message.displayId);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(repository.acknowledgeCalls, 3);
    expect(
      container.read(userMessageControllerProvider).displayedThisSession,
      isTrue,
    );
  });
}
