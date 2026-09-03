import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/features/user_message/user_message_action_dispatcher.dart';
import 'package:lantern/features/user_message/user_message_host.dart';
import 'package:lantern/features/user_message/user_message_repository.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';

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
          overrides: [userMessageRepositoryProvider.overrideWithValue(source)],
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

class _FakeRadianceMessageSource implements UserMessageRepository {
  final _events = StreamController<void>.broadcast();
  final acknowledged = <String>[];

  @override
  Stream<void> get messageAvailable => _events.stream;

  @override
  Future<void> acknowledge(String displayId) async {
    acknowledged.add(displayId);
  }

  @override
  Future<UserMessage?> current() async {
    return UserMessage(
      displayId: 'campaign-1:generation-1',
      campaignId: 'campaign-1',
      revisionId: 'revision-1',
      deliveryId: 'delivery-1',
      surface: UserMessageSurface.snackbar,
      locale: 'en-US',
      body: 'Message from fake Radiance',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> setActive(bool active) async {}

  Future<void> dispose() => _events.close();
}
