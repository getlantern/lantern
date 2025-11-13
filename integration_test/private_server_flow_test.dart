import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

import '../test/fakes/fake_private_server_notifier.dart';
import '../test/fakes/fake_local_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
MACOS_APP_GROUP=lantern.test.group
STRIPE_PUBLISHABLE=
WINDOWS_APP_USER_MODEL_ID=
WINDOWS_GUID=
''');

    await sl.reset();
    final appRouter = AppRouter();
    sl.registerLazySingleton<AppRouter>(() => appRouter);

    sl.registerSingleton<LocalStorageService>(FakeLocalStorageService());
  });
  testWidgets(
      'Private server flow: GCP -> account -> project -> location -> name -> deploy',
      (WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      privateServerProvider
          .overrideWith(() => FakePrivateServerNotifier()),
    ]);

    final appRouter = sl<AppRouter>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: appRouter.config(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    appRouter.replaceAll([
      PrivateServerDetails(
        accounts: const ['alice@example.com', 'bob@example.com'],
        provider: CloudProvider.googleCloud,
      ),
    ]);

    await tester.pumpAndSettle();

    // pick account
    final accountDd = find.byKey(const Key('psd.accountDropdown'));
    expect(accountDd, findsOneWidget);
    await tester.tap(accountDd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('alice@example.com').last);
    await tester.pumpAndSettle();

    // pick project
    final projectDd = find.byKey(const Key('psd.projectDropdown'));
    expect(projectDd, findsOneWidget);
    await tester.tap(projectDd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('billing-main').last);
    await tester.pumpAndSettle();

    // open location picker
    final chooseLocBtn = find.byKey(const Key('psd.chooseLocation'));
    expect(chooseLocBtn, findsOneWidget);
    await tester.tap(chooseLocBtn);
    await tester.pumpAndSettle();

    // pick first location
    final firstLoc = find.byKey(const Key('psl.location.0'));
    expect(firstLoc, findsOneWidget);
    await tester.tap(firstLoc);
    await tester.pumpAndSettle();

    // enter server name
    final nameField = find.byKey(const Key('psd.serverName'));
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'My Test Server');
    await tester.pumpAndSettle();

    // start deployment
    final startBtn = find.byKey(const Key('psd.startDeployment'));
    expect(startBtn, findsOneWidget);
    await tester.tap(startBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Deploying Private Server'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // success dialog should appear
    expect(find.textContaining('private_server_ready'.i18n), findsOneWidget);

    final fakeStore = sl<LocalStorageService>() as FakeLocalStorageService;
    expect(fakeStore.lastSaved?.serverName, 'My Test Server');
  });
}
