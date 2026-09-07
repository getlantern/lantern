import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service.dart';

class FakeUserMessageService implements LanternService {
  final events = StreamController<AppEvent>.broadcast();
  UserMessage? currentMessage;
  Failure? currentFailure;
  Failure? acknowledgeFailure;
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
  Stream<AppEvent> watchAppEvents() => events.stream;

  void emitMessageAvailable() => events.add(
    AppEvent(eventType: AppEvent.userMessageAvailable, message: ''),
  );

  @override
  Future<Either<Failure, UserMessage?>> currentUserMessage() async {
    currentCalls++;
    if (onCurrent case final read?) return right(await read());
    if (currentError case final error?) throw error;
    if (currentFailure case final failure?) return left(failure);
    return right(currentMessage);
  }

  @override
  Future<Either<Failure, Unit>> refreshUserMessages() async {
    refreshCalls++;
    if (refreshError case final error?) throw error;
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> acknowledgeUserMessage(
    String displayId,
    String accountId,
  ) async {
    acknowledgeCalls++;
    if (acknowledgeError case final error?) throw error;
    if (acknowledgeFailure case final failure?) return left(failure);
    acknowledged.add(displayId);
    acknowledgedAccounts.add(accountId);
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setUserMessageActivity(bool active) async {
    activity.add(active);
    await onSetActive?.call(active);
    return right(unit);
  }

  Future<void> dispose() => events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
