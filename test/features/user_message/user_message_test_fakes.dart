import 'dart:async';

import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/features/user_message/user_message_repository.dart';

class FakeUserMessageRepository implements UserMessageRepository {
  final events = StreamController<void>.broadcast();
  UserMessage? currentMessage;
  Object? currentError;
  Object? refreshError;
  Object? acknowledgeError;
  Future<UserMessage?> Function()? onCurrent;
  Future<void> Function(bool)? onSetActive;
  int acknowledgeCalls = 0;
  int currentCalls = 0;
  int refreshCalls = 0;
  final activity = <bool>[];
  final acknowledged = <String>[];
  final acknowledgedAccounts = <String>[];

  @override
  Stream<void> get messageAvailable => events.stream;

  @override
  Future<UserMessage?> current() async {
    currentCalls++;
    if (onCurrent case final read?) return read();
    if (currentError case final error?) throw error;
    return currentMessage;
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
    if (refreshError case final error?) throw error;
  }

  @override
  Future<void> acknowledge(String displayId, String accountId) async {
    acknowledgeCalls++;
    if (acknowledgeError case final error?) throw error;
    acknowledged.add(displayId);
    acknowledgedAccounts.add(accountId);
  }

  @override
  Future<void> setActive(bool active) async {
    activity.add(active);
    await onSetActive?.call(active);
  }

  Future<void> dispose() => events.close();
}

UserMessage testUserMessage({
  String displayId = 'campaign-1:generation-1',
  String accountId = '12345',
  String body = 'A message from Lantern',
  String? buttonLabel,
  UserMessageAction? action,
  DateTime? expiresAt,
}) {
  return UserMessage(
    accountId: accountId,
    displayId: displayId,
    campaignId: 'campaign-1',
    revisionId: 'revision-1',
    deliveryId: 'delivery-1',
    surface: UserMessageSurface.snackbar,
    locale: 'en-US',
    body: body,
    buttonLabel: buttonLabel,
    action: action,
    expiresAt:
        expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

Future<void> pumpProviderQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
