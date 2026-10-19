import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/auth/lantern_pro_license.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

const _email = 'person@example.com';
const _formattedLicense = 'ABCDE-FGHIJ-KLMNO-PQRST-UVWXY';
const _licenseScreen = LanternProLicense(email: _email, code: 'email-code');

class _FakeLanternService implements LanternService {
  final activations = <({String email, String resellerCode})>[];

  @override
  Future<Either<Failure, Unit>> activationCode({
    required String email,
    required String resellerCode,
  }) async {
    activations.add((email: email, resellerCode: resellerCode));
    return left(
      Failure(
        error: 'test_activation_failure',
        localizedErrorMessage: 'Unable to activate this test license',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHomeNotifier extends HomeNotifier {
  @override
  Future<UserResponseModel> build() async => const UserResponseModel(
    legacyID: 1,
    legacyToken: 'test-token',
    emailConfirmed: true,
    success: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, String>> englishTranslations;
  late _FakeLanternService service;

  setUpAll(() async {
    englishTranslations = await GettextImporter().fromAssetFile(
      'en',
      'assets/locales/en.po',
    );
  });

  setUp(() {
    service = _FakeLanternService();
    final previousTranslations = Localization.translations;
    final previousLocale = Localization.defaultLocale;
    addTearDown(() {
      Localization.translations = previousTranslations;
      Localization.defaultLocale = previousLocale;
    });
    Localization.translations =
        Translations.byLocale('en') + englishTranslations;
    Localization.defaultLocale = 'en';
  });

  Widget harness({Widget home = _licenseScreen}) => ProviderScope(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      homeProvider.overrideWith(_FakeHomeNotifier.new),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      child: GlobalLoaderOverlay(
        child: MaterialApp(theme: AppTheme.appTheme(), home: home),
      ),
    ),
  );

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  void expectPrivateKeyboard(WidgetTester tester) {
    final input = field(tester);
    expect(input.keyboardType, TextInputType.visiblePassword);
    expect(input.autocorrect, isFalse);
    expect(input.enableSuggestions, isFalse);
    expect(input.enableIMEPersonalizedLearning, isFalse);
  }

  testWidgets('starts hidden and keeps keyboard privacy when revealed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(field(tester).obscureText, isTrue);
    expectPrivateKeyboard(tester);
    expect(find.byTooltip('Show license'), findsOneWidget);
    expect(find.text('0/25'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextFormField), _formattedLicense);
    await tester.pump();
    final hiddenSemantics = tester
        .getSemantics(find.byType(EditableText))
        .getSemanticsData();
    expect(hiddenSemantics.flagsCollection.isObscured, isTrue);
    expect(
      hiddenSemantics.value,
      field(tester).obscuringCharacter * _formattedLicense.length,
    );
    final showSemantics = tester
        .getSemantics(find.byTooltip('Show license'))
        .getSemanticsData();
    expect(showSemantics.flagsCollection.isButton, isTrue);
    expect(showSemantics.tooltip, 'Show license');

    await tester.tap(find.byTooltip('Show license'));
    await tester.pump();

    expect(field(tester).obscureText, isFalse);
    expectPrivateKeyboard(tester);
    expect(find.byTooltip('Hide license'), findsOneWidget);
    final revealedSemantics = tester
        .getSemantics(find.byType(EditableText))
        .getSemanticsData();
    expect(revealedSemantics.flagsCollection.isObscured, isFalse);
    expect(revealedSemantics.value, _formattedLicense);
    expect(
      tester
          .getSemantics(find.byTooltip('Hide license'))
          .getSemanticsData()
          .tooltip,
      'Hide license',
    );
    semantics.dispose();
  });

  testWidgets('toggles preserve formatting, selection, count, and validity', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextFormField), 'abcde-fg!hij');
    await tester.pump();

    final controller = field(tester).controller;
    expect(controller.text, 'ABCDE-FGHIJ');
    expect(find.text('10/25'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    const selection = TextSelection(baseOffset: 2, extentOffset: 8);
    controller.selection = selection;
    await tester.pump();

    await tester.tap(find.byTooltip('Show license'));
    await tester.pump();

    expect(field(tester).controller, same(controller));
    expect(controller.text, 'ABCDE-FGHIJ');
    expect(controller.selection, selection);
    expect(find.text('10/25'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextFormField),
      'abcde fghij-klmno_pqrst uvwxy-extra',
    );
    await tester.pump();
    controller.selection = selection;
    await tester.pump();
    expect(controller.text, _formattedLicense);
    expect(find.text('25/25'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byTooltip('Hide license'));
    await tester.pump();

    expect(field(tester).obscureText, isTrue);
    expect(field(tester).controller, same(controller));
    expect(controller.text, _formattedLicense);
    expect(controller.selection, selection);
    expect(find.text('25/25'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(service.activations, isEmpty);
  });

  testWidgets('reopening the screen resets visibility to hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => _licenseScreen)),
              child: const Text('Open license'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open license'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show license'));
    await tester.pump();
    expect(field(tester).obscureText, isFalse);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open license'));
    await tester.pumpAndSettle();

    expect(field(tester).obscureText, isTrue);
    expect(find.byTooltip('Show license'), findsOneWidget);
  });

  testWidgets('Enter on the visibility button toggles without activation', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextFormField), _formattedLicense);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<IconButton>()
          ?.tooltip,
      'Show license',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(field(tester).obscureText, isFalse);
    expect(service.activations, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump();
    expect(field(tester).obscureText, isTrue);
    expect(service.activations, isEmpty);
  });

  testWidgets('activation submits the actual formatted license while hidden', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.enterText(
      find.byType(TextFormField),
      'abcde fghij klmno pqrst uvwxy',
    );
    await tester.pump();
    expect(field(tester).obscureText, isTrue);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(service.activations, [
      (email: _email, resellerCode: _formattedLicense),
    ]);
    expect(find.text('Unable to activate this test license'), findsOneWidget);
  });
}
