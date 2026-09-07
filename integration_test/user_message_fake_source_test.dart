import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/user_message/user_message_action_dispatcher.dart';
import 'package:lantern/features/user_message/user_message_host.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'presents and acknowledges a message from a fake Radiance source',
    (tester) async {
      final source = _FakeRadianceMessageSource();
      addTearDown(source.dispose);
      final observer = UserMessageRouteObserver();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [lanternServiceProvider.overrideWithValue(source)],
          child: MaterialApp(
            navigatorObservers: [observer],
            builder: (context, child) => UserMessageHost(
              routeObserver: observer,
              actionDispatcher: UserMessageActionDispatcher(
                openHttpsUrl: (_) async {},
                openPlans: () async {},
              ),
              enabled: true,
              criticalOverlayVisible: (_) => false,
              retryInterval: const Duration(milliseconds: 20),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Lantern shell')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Message from fake Radiance'), findsOneWidget);
      expect(source.acknowledged, ['campaign-1:generation-1']);
    },
  );
}

class _FakeRadianceMessageSource implements LanternService {
  final _events = StreamController<AppEvent>.broadcast();
  final acknowledged = <String>[];

  @override
  Stream<AppEvent> watchAppEvents() => _events.stream;

  @override
  Future<Either<Failure, Unit>> acknowledgeUserMessage(
    String displayId,
    String accountId,
  ) async {
    acknowledged.add(displayId);
    return right(unit);
  }

  @override
  Future<Either<Failure, UserMessage?>> currentUserMessage() async {
    return right(
      UserMessage(
        accountId: '12345',
        displayId: 'campaign-1:generation-1',
        campaignId: 'campaign-1',
        revisionId: 'revision-1',
        deliveryId: 'delivery-1',
        surface: UserMessageSurface.snackbar,
        locale: 'en-US',
        body: 'Message from fake Radiance',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> refreshUserMessages() async => right(unit);

  @override
  Future<Either<Failure, Unit>> setUserMessageActivity(bool active) async =>
      right(unit);

  Future<void> dispose() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
