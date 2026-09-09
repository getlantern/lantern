import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/user_message/user_message_controller.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

import 'user_message_test_fakes.dart';

void main() {
  late FakeUserMessageService service;
  late ProviderContainer container;

  setUp(() {
    service = FakeUserMessageService();
    container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
  });

  tearDown(() async {
    container.dispose();
    await service.dispose();
  });

  test('loads current state at startup and reloads on availability', () async {
    final first = testUserMessage();
    service.currentMessage = first;
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();

    expect(container.read(userMessageControllerProvider).pending, same(first));
    expect(service.refreshCalls, 1);
    expect(service.activity, [true]);

    final second = testUserMessage(displayId: 'campaign-2:generation-1');
    service.currentMessage = second;
    service.events.add(AppEvent(eventType: 'config', message: 'ignored'));
    await pumpProviderQueue();
    expect(service.currentCalls, 1);
    expect(container.read(userMessageControllerProvider).pending, same(first));
    service.emitMessageAvailable();
    await pumpProviderQueue();

    expect(container.read(userMessageControllerProvider).pending, same(second));
    expect(service.currentCalls, 2);
  });

  test('claims once and acknowledges only after presentation', () async {
    final message = testUserMessage();
    service.currentMessage = message;
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();
    final controller = container.read(userMessageControllerProvider.notifier);

    expect(controller.claimForPresentation(DateTime.now()), same(message));
    expect(service.acknowledged, isEmpty);
    expect(controller.claimForPresentation(DateTime.now()), isNull);

    await controller.markPresented(message.displayId);
    expect(service.acknowledged, [message.displayId]);
    expect(service.acknowledgedAccounts, [message.accountId]);
    expect(
      container.read(userMessageControllerProvider).displayedThisSession,
      isTrue,
    );

    service.currentMessage = testUserMessage(
      displayId: 'campaign-2:generation-1',
    );
    service.emitMessageAvailable();
    await pumpProviderQueue();
    expect(container.read(userMessageControllerProvider).pending, isNull);
  });

  test(
    'drops stale content when the native bridge returns a failure',
    () async {
      service.currentMessage = testUserMessage();
      container.read(userMessageControllerProvider);
      await pumpProviderQueue();
      service.currentFailure = Failure(
        error: 'native details must not escape into UI state',
        localizedErrorMessage: 'localized content must not escape either',
      );
      await container
          .read(userMessageControllerProvider.notifier)
          .loadCurrent();
      expect(container.read(userMessageControllerProvider).pending, isNull);
      expect(
        container.read(userMessageControllerProvider).displayedThisSession,
        isFalse,
      );
    },
  );

  test('drops expired messages before they can be claimed', () async {
    service.currentMessage = testUserMessage(
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();

    final controller = container.read(userMessageControllerProvider.notifier);
    expect(controller.claimForPresentation(DateTime.now()), isNull);
    expect(container.read(userMessageControllerProvider).pending, isNull);
    expect(service.acknowledged, isEmpty);
  });

  test(
    'foreground reconciliation pulls current state and requests refresh',
    () async {
      container.read(userMessageControllerProvider);
      await pumpProviderQueue();
      service.refreshCalls = 0;
      final message = testUserMessage();
      service.currentMessage = message;

      await container
          .read(userMessageControllerProvider.notifier)
          .onForegrounded();

      expect(
        container.read(userMessageControllerProvider).pending,
        same(message),
      );
      expect(service.refreshCalls, 1);
      expect(service.activity.last, isTrue);
    },
  );

  test('pauses polling while backgrounded', () async {
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();

    await container
        .read(userMessageControllerProvider.notifier)
        .onBackgrounded();

    expect(service.activity, [true, false]);
  });

  test('serializes native lifecycle updates', () async {
    container.read(userMessageControllerProvider);
    await pumpProviderQueue();
    service.activity.clear();
    final backgroundCompleted = Completer<void>();
    service.onSetActive = (active) async {
      if (!active) await backgroundCompleted.future;
    };
    final controller = container.read(userMessageControllerProvider.notifier);
    final background = controller.onBackgrounded();
    await pumpProviderQueue();
    final foreground = controller.onForegrounded();
    await pumpProviderQueue();
    expect(service.activity, [false]);
    backgroundCompleted.complete();
    await Future.wait([background, foreground]);
    expect(service.activity, [false, true]);
  });

  test(
    'clears queued content while revalidating the current account',
    () async {
      service.currentMessage = testUserMessage();
      container.read(userMessageControllerProvider);
      await pumpProviderQueue();
      final pendingRead = Completer<UserMessage?>();
      service.onCurrent = () => pendingRead.future;
      final load = container
          .read(userMessageControllerProvider.notifier)
          .loadCurrent();
      expect(container.read(userMessageControllerProvider).pending, isNull);
      pendingRead.complete(null);
      await load;
      expect(container.read(userMessageControllerProvider).pending, isNull);
    },
  );

  test(
    'coalesces lifecycle changes without a stale foreground refresh',
    () async {
      container.read(userMessageControllerProvider);
      await pumpProviderQueue();
      service.activity.clear();
      service.refreshCalls = 0;
      final backgroundCompleted = Completer<void>();
      service.onSetActive = (_) => backgroundCompleted.future;
      final controller = container.read(userMessageControllerProvider.notifier);
      final background = controller.onBackgrounded();
      final foreground = controller.onForegrounded();
      final backgroundAgain = controller.onBackgrounded();
      backgroundCompleted.complete();
      await Future.wait([background, foreground, backgroundAgain]);
      expect(service.activity, [false, false]);
      expect(service.refreshCalls, 0);
    },
  );

  testWidgets('retries acknowledgment without displaying again', (
    tester,
  ) async {
    service.currentMessage = testUserMessage();
    service.acknowledgeError = Exception('IPC unavailable');
    container.read(userMessageControllerProvider);
    await tester.pump();
    final controller = container.read(userMessageControllerProvider.notifier);
    final message = controller.claimForPresentation(DateTime.now())!;
    await controller.markPresented(message.displayId);
    expect(service.acknowledgeCalls, 1);
    expect(controller.claimForPresentation(DateTime.now()), isNull);
    service.acknowledgeError = null;
    await tester.pump(const Duration(seconds: 1));
    expect(service.acknowledged, [message.displayId]);
    expect(service.acknowledgedAccounts, [message.accountId]);
  });

  testWidgets('retries acknowledgment when the bridge returns a failure', (
    tester,
  ) async {
    service.currentMessage = testUserMessage();
    service.acknowledgeFailure = Failure(
      error: 'IPC unavailable',
      localizedErrorMessage: '',
    );
    container.read(userMessageControllerProvider);
    await tester.pump();
    final controller = container.read(userMessageControllerProvider.notifier);
    final message = controller.claimForPresentation(DateTime.now())!;
    await controller.markPresented(message.displayId);
    expect(service.acknowledgeCalls, 1);
    expect(service.acknowledged, isEmpty);
    service.acknowledgeFailure = null;
    await tester.pump(const Duration(seconds: 1));
    expect(service.acknowledged, [message.displayId]);
    expect(service.acknowledgedAccounts, [message.accountId]);
  });

  testWidgets('abandons a retry after switching accounts', (tester) async {
    service.currentMessage = testUserMessage();
    service.acknowledgeError = Exception('IPC unavailable');
    container.read(userMessageControllerProvider);
    await tester.pump();
    final controller = container.read(userMessageControllerProvider.notifier);
    final message = controller.claimForPresentation(DateTime.now())!;
    await controller.markPresented(message.displayId);
    service.currentMessage = testUserMessage(accountId: '67890');
    service.acknowledgeError = null;
    await tester.pump(const Duration(seconds: 1));
    expect(service.acknowledgeCalls, 1);
    expect(service.acknowledged, isEmpty);
  });

  testWidgets('bounds failed acknowledgment attempts', (tester) async {
    service.currentMessage = testUserMessage();
    service.acknowledgeError = Exception('IPC unavailable');
    container.read(userMessageControllerProvider);
    await tester.pump();
    final controller = container.read(userMessageControllerProvider.notifier);
    final message = controller.claimForPresentation(DateTime.now())!;
    await controller.markPresented(message.displayId);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(service.acknowledgeCalls, 3);
    expect(
      container.read(userMessageControllerProvider).displayedThisSession,
      isTrue,
    );
  });
}
