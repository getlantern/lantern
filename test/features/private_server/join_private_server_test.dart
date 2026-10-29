import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/private_server/join_private_server.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

class _PrivateServerNotifier extends PrivateServerNotifier {
  final submittedURLs = <String>[];

  @override
  PrivateServerStatus build() => const PrivateServerStatus(status: 'initial');

  @override
  Future<Either<Failure, List<String>>> addServerBasedOnURLs(
    String urls,
    bool skipCertVerification,
  ) async {
    submittedURLs.add(urls);
    return left(
      Failure(error: 'rejected', localizedErrorMessage: 'Server rejected'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Localization.loadTranslations);

  setUpAll(() {
    final allowRuntimeFetching = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(() {
      GoogleFonts.config.allowRuntimeFetching = allowRuntimeFetching;
    });
  });

  Future<_PrivateServerNotifier> submit(
    WidgetTester tester,
    String accessKey,
  ) async {
    final notifier = _PrivateServerNotifier();
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privateServerProvider.overrideWith(() => notifier)],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: GlobalLoaderOverlay(
            child: MaterialApp(
              theme: AppTheme.appTheme(),
              home: JoinPrivateServer(
                deepLinkData: {'accessKey': accessKey, 'alias': 'My server'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('join_private_server.submit'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return notifier;
  }

  for (final field in ['ip', 'token', 'name']) {
    testWidgets('malformed invite $field shows an error without importing', (
      tester,
    ) async {
      final parameters = {
        'ip': '192.0.2.1',
        'port': '443',
        'token': 'test',
        'name': 'Shared',
        field: '%FF',
      }.entries.map((entry) => '${entry.key}=${entry.value}').join('&');
      final notifier = await submit(
        tester,
        'lantern://private-server?$parameters',
      );

      expect(notifier.submittedURLs, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('invalid_server_details'.i18n), findsOneWidget);
    });
  }

  testWidgets('invite nickname is passed to the importer', (tester) async {
    final notifier = await submit(
      tester,
      'https://lantern.io/private-server?ip=192.0.2.1&port=443&token=test&name=Shared',
    );

    expect(notifier.submittedURLs, hasLength(1));
    expect(Uri.parse(notifier.submittedURLs.single).queryParameters, {
      'ip': '192.0.2.1',
      'port': '443',
      'token': 'test',
      'name': 'My server',
    });
    expect(find.text('Server rejected'), findsOneWidget);
  });

  for (final accessKey in [
    'vmess://eyJhZGQiOiJleGFtcGxlLmNvbSIsInBvcnQiOiI0NDMifQ==',
    'ss://test@example.com:443?plugin=%FF',
  ]) {
    testWidgets('non-invite access key stays unchanged: $accessKey', (
      tester,
    ) async {
      final notifier = await submit(tester, accessKey);

      expect(notifier.submittedURLs, [accessKey]);
      expect(find.text('Server rejected'), findsOneWidget);
    });
  }
}
