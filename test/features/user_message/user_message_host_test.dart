import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/features/user_message/user_message_action_dispatcher.dart';
import 'package:lantern/features/user_message/user_message_host.dart';
import 'package:lantern/features/user_message/user_message_repository.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';

import 'user_message_test_fakes.dart';

class _Actions {
  final urls = <Uri>[];
  int plans = 0;

  UserMessageActionDispatcher get dispatcher => UserMessageActionDispatcher(
    openHttpsUrl: (uri) async => urls.add(uri),
    openPlans: () async => plans++,
  );
}

Widget _harness({
  required FakeUserMessageRepository repository,
  required UserMessageRouteObserver observer,
  required UserMessageActionDispatcher dispatcher,
  Widget? home,
  bool enabled = true,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  bool Function(BuildContext)? criticalOverlayVisible,
  DateTime Function()? now,
  ValueListenable<bool>? enabledListenable,
  ValueListenable<bool>? hostMountedListenable,
  GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey,
}) {
  return ProviderScope(
    overrides: [userMessageRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [observer],
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        Widget withMediaQuery(Widget content) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: content,
        );

        Widget buildHost(bool hostEnabled) => withMediaQuery(
          UserMessageHost(
            routeObserver: observer,
            actionDispatcher: dispatcher,
            enabled: hostEnabled,
            retryInterval: const Duration(milliseconds: 20),
            criticalOverlayVisible: criticalOverlayVisible ?? (_) => false,
            now: now,
            child: appChild,
          ),
        );

        Widget buildMountedHost(bool hostEnabled) {
          if (hostMountedListenable case final listenable?) {
            return ValueListenableBuilder<bool>(
              valueListenable: listenable,
              builder: (_, hostMounted, _) => hostMounted
                  ? buildHost(hostEnabled)
                  : withMediaQuery(appChild),
            );
          }
          return buildHost(hostEnabled);
        }

        if (enabledListenable case final listenable?) {
          return ValueListenableBuilder<bool>(
            valueListenable: listenable,
            builder: (_, hostEnabled, _) => buildMountedHost(hostEnabled),
          );
        }
        return buildMountedHost(enabled);
      },
      home: home ?? const Scaffold(body: Text('home')),
    ),
  );
}

Future<void> _pumpToSnackbar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'presents plain text, dismiss action, and acknowledges on visible',
    (tester) async {
      final repository = FakeUserMessageRepository()
        ..currentMessage = testUserMessage(body: 'Service announcement');
      addTearDown(repository.dispose);
      final observer = UserMessageRouteObserver();

      await tester.pumpWidget(
        _harness(
          repository: repository,
          observer: observer,
          dispatcher: _Actions().dispatcher,
        ),
      );
      await _pumpToSnackbar(tester);

      expect(find.text('Service announcement'), findsOneWidget);
      expect(find.byKey(UserMessageHost.bodyKey), findsOneWidget);
      expect(find.byKey(UserMessageHost.closeKey), findsOneWidget);
      expect(repository.acknowledged, ['campaign-1:generation-1']);
    },
  );

  testWidgets(
    'routes a validated CTA and exposes keyboard-focusable controls',
    (tester) async {
      final actions = _Actions();
      final repository = FakeUserMessageRepository()
        ..currentMessage = testUserMessage(
          buttonLabel: 'Learn more',
          action: UserMessageAction(
            type: UserMessageActionType.openHttpsUrl,
            url: Uri.parse('https://getlantern.org/learn'),
          ),
        );
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        _harness(
          repository: repository,
          observer: UserMessageRouteObserver(),
          dispatcher: actions.dispatcher,
        ),
      );
      await _pumpToSnackbar(tester);

      final actionFinder = find.byKey(UserMessageHost.actionKey);
      expect(actionFinder, findsOneWidget);
      expect(
        find.descendant(of: actionFinder, matching: find.byType(TextButton)),
        findsOneWidget,
      );
      expect(find.byKey(UserMessageHost.closeKey), findsOneWidget);
      await tester.tap(find.byKey(UserMessageHost.actionKey));
      await tester.pump();
      expect(actions.urls, [Uri.parse('https://getlantern.org/learn')]);
    },
  );

  testWidgets('enforces one displayed message per Flutter session', (
    tester,
  ) async {
    final repository = FakeUserMessageRepository()
      ..currentMessage = testUserMessage(body: 'First message');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _harness(
        repository: repository,
        observer: UserMessageRouteObserver(),
        dispatcher: _Actions().dispatcher,
      ),
    );
    await _pumpToSnackbar(tester);
    expect(repository.acknowledged, hasLength(1));

    repository.currentMessage = testUserMessage(
      displayId: 'campaign-2:generation-1',
      body: 'Second message',
    );
    repository.events.add(null);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Second message'), findsNothing);
    expect(repository.acknowledged, ['campaign-1:generation-1']);
  });

  testWidgets('queues in background and reconciles on foreground', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    final repository = FakeUserMessageRepository()
      ..currentMessage = testUserMessage(body: 'Foreground only');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _harness(
        repository: repository,
        observer: UserMessageRouteObserver(),
        dispatcher: _Actions().dispatcher,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Foreground only'), findsNothing);
    expect(repository.acknowledged, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpToSnackbar(tester);
    expect(find.text('Foreground only'), findsOneWidget);
  });

  testWidgets('queues until the main shell enables presentation', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    final repository = FakeUserMessageRepository()
      ..currentMessage = testUserMessage(body: 'After onboarding');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _harness(
        repository: repository,
        observer: UserMessageRouteObserver(),
        dispatcher: _Actions().dispatcher,
        enabledListenable: enabled,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('After onboarding'), findsNothing);
    expect(repository.acknowledged, isEmpty);

    enabled.value = true;
    await _pumpToSnackbar(tester);
    expect(find.text('After onboarding'), findsOneWidget);
    expect(repository.acknowledged, ['campaign-1:generation-1']);
  });

  testWidgets('releases an unshown claim when the host is disposed', (
    tester,
  ) async {
    final hostMounted = ValueNotifier(true);
    addTearDown(hostMounted.dispose);
    final repository = FakeUserMessageRepository()
      ..currentMessage = testUserMessage(body: 'Survives host replacement');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _harness(
        repository: repository,
        observer: UserMessageRouteObserver(),
        dispatcher: _Actions().dispatcher,
        hostMountedListenable: hostMounted,
      ),
    );
    await tester.pump();

    hostMounted.value = false;
    await tester.pump();
    expect(repository.acknowledged, isEmpty);

    hostMounted.value = true;
    await _pumpToSnackbar(tester);
    expect(find.text('Survives host replacement'), findsOneWidget);
    expect(repository.acknowledged, ['campaign-1:generation-1']);
  });

  testWidgets(
    'does not remove an application snackbar when the host deactivates',
    (tester) async {
      final hostMounted = ValueNotifier(true);
      addTearDown(hostMounted.dispose);
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final repository = FakeUserMessageRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        _harness(
          repository: repository,
          observer: UserMessageRouteObserver(),
          dispatcher: _Actions().dispatcher,
          hostMountedListenable: hostMounted,
          scaffoldMessengerKey: messengerKey,
        ),
      );
      await tester.pump();
      messengerKey.currentState!.showSnackBar(
        const SnackBar(
          content: Text('Application snackbar'),
          duration: Duration(hours: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      repository.currentMessage = testUserMessage(body: 'Queued user message');
      repository.events.add(null);
      await _pumpToSnackbar(tester);
      expect(find.text('Application snackbar'), findsOneWidget);
      expect(find.text('Queued user message'), findsOneWidget);
      expect(repository.acknowledged, ['campaign-1:generation-1']);

      hostMounted.value = false;
      await tester.pump();
      await tester.pump();
      expect(find.text('Application snackbar'), findsOneWidget);
      expect(find.text('Queued user message'), findsNothing);

      hostMounted.value = true;
      await tester.pump();
      await _pumpToSnackbar(tester);
      expect(find.text('Application snackbar'), findsOneWidget);
      expect(find.text('Queued user message'), findsNothing);
      expect(repository.acknowledged, ['campaign-1:generation-1']);
    },
  );

  testWidgets(
    'does not remove an application snackbar when a message expires before display',
    (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final baseTime = DateTime.now().toUtc();
      var clockReads = 0;
      final repository = FakeUserMessageRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        _harness(
          repository: repository,
          observer: UserMessageRouteObserver(),
          dispatcher: _Actions().dispatcher,
          scaffoldMessengerKey: messengerKey,
          now: () => clockReads++ == 0
              ? baseTime
              : baseTime.add(const Duration(seconds: 2)),
        ),
      );
      await tester.pump();
      messengerKey.currentState!.showSnackBar(
        const SnackBar(
          content: Text('Application snackbar'),
          duration: Duration(hours: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      repository.currentMessage = testUserMessage(
        body: 'Expiring user message',
        expiresAt: baseTime.add(const Duration(seconds: 1)),
      );
      repository.events.add(null);
      await _pumpToSnackbar(tester);

      expect(find.text('Application snackbar'), findsOneWidget);
      expect(find.text('Expiring user message'), findsNothing);
      expect(repository.acknowledged, isEmpty);
    },
  );

  testWidgets('does not wedge when a claimed message expires before display', (
    tester,
  ) async {
    final baseTime = DateTime.now().toUtc();
    var clockReads = 0;
    final repository = FakeUserMessageRepository()
      ..currentMessage = testUserMessage(
        body: 'Expired during presentation',
        expiresAt: baseTime.add(const Duration(seconds: 1)),
      );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _harness(
        repository: repository,
        observer: UserMessageRouteObserver(),
        dispatcher: _Actions().dispatcher,
        now: () => clockReads++ == 0
            ? baseTime
            : baseTime.add(const Duration(seconds: 2)),
      ),
    );
    await _pumpToSnackbar(tester);
    expect(find.text('Expired during presentation'), findsNothing);
    expect(repository.acknowledged, isEmpty);

    repository.currentMessage = testUserMessage(
      displayId: 'campaign-2:generation-1',
      body: 'Next eligible message',
      expiresAt: baseTime.add(const Duration(hours: 1)),
    );
    repository.events.add(null);
    await _pumpToSnackbar(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Next eligible message'), findsOneWidget);
    expect(repository.acknowledged, ['campaign-2:generation-1']);
  });

  testWidgets('queues behind a dialog and rechecks expiration before display', (
    tester,
  ) async {
    final repository = FakeUserMessageRepository();
    addTearDown(repository.dispose);
    final observer = UserMessageRouteObserver();
    final baseTime = DateTime.now().toUtc();
    var currentTime = baseTime;

    await tester.pumpWidget(
      _harness(
        repository: repository,
        observer: observer,
        dispatcher: _Actions().dispatcher,
        now: () => currentTime,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('critical')),
              ),
              child: const Text('open dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    repository.currentMessage = testUserMessage(
      body: 'Expires behind dialog',
      expiresAt: baseTime.add(const Duration(seconds: 1)),
    );
    repository.events.add(null);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Expires behind dialog'), findsNothing);

    currentTime = baseTime.add(const Duration(seconds: 2));
    Navigator.of(tester.element(find.text('critical'))).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Expires behind dialog'), findsNothing);
    expect(repository.acknowledged, isEmpty);
  });

  testWidgets('dismisses a visible message when a critical dialog opens', (
    tester,
  ) async {
    final repository = FakeUserMessageRepository()
      ..currentMessage = testUserMessage(body: 'Visible before dialog');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _harness(
        repository: repository,
        observer: UserMessageRouteObserver(),
        dispatcher: _Actions().dispatcher,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('critical')),
              ),
              child: const Text('open dialog'),
            ),
          ),
        ),
      ),
    );
    await _pumpToSnackbar(tester);
    expect(find.text('Visible before dialog'), findsOneWidget);
    expect(repository.acknowledged, ['campaign-1:generation-1']);

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('critical'), findsOneWidget);
    expect(find.text('Visible before dialog'), findsNothing);
    expect(repository.acknowledged, ['campaign-1:generation-1']);
  });

  testWidgets(
    'supports RTL, large text, long copy, and live-region semantics',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final body = List.filled(18, 'رسالة طويلة من لانترن').join(' ');
        final repository = FakeUserMessageRepository()
          ..currentMessage = testUserMessage(body: body);
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          _harness(
            repository: repository,
            observer: UserMessageRouteObserver(),
            dispatcher: _Actions().dispatcher,
            locale: const Locale('ar'),
            textScaler: const TextScaler.linear(2),
          ),
        );
        await _pumpToSnackbar(tester);

        final bodyFinder = find.byKey(UserMessageHost.bodyKey);
        expect(bodyFinder, findsOneWidget);
        expect(
          Directionality.of(tester.element(bodyFinder)),
          TextDirection.rtl,
        );
        expect(find.bySemanticsLabel(body), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
