import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart'
    show AppRadioButton, AppTile;
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/main.dart' as app;
import 'package:lantern/core/localization/localization_constants.dart'
    show displayLanguage;
import 'package:lantern/features/setting/appearance.dart'
    show appearanceModeLabel;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';

final _appearanceList = find.byKey(const Key('appearance.list'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerSettingSmokeTests();
}

/// Exposed so an aggregator entrypoint (android_all_e2e_test.dart) can
/// register this suite alongside others.
void registerSettingSmokeTests() {
  group('Settings smoke test', () {
    testWidgets('language change persists and can be reverted', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openLanguage();
      try {
        // Selecting a language pops back to Settings, whose language tile
        // must now show the new language's display name.
        await _selectRadio(tester, 'es_ES');
        expect(
          _settingTileTrailing(
            'setting.language_tile',
            displayLanguage('es_ES'),
          ),
          findsOneWidget,
        );

        // Reopen through the full UI flow; the selection must have stuck.
        await appRobot.goBack();
        await appRobot.openLanguage();
        expect(_isRadioSelected(tester, 'es_ES'), isTrue);
      } finally {
        // Revert to English so later scenarios see the default locale.
        if (_radio('en_US').evaluate().isNotEmpty) {
          await _selectRadio(tester, 'en_US');
        }
        await appRobot.resetToRoot();
      }
    });

    testWidgets('appearance change applies the theme mode', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openAppearance();

      final original = _appThemeMode(tester);
      final target = original == ThemeMode.dark ? 'light' : 'dark';
      e2eLog('Theme mode: $original -> $target');
      final targetMode = target == 'dark' ? ThemeMode.dark : ThemeMode.light;
      try {
        await _selectRadio(tester, target);
        expect(_appThemeMode(tester), targetMode);

        // The Settings appearance tile must reflect the new mode.
        await _ensureOnSettings(appRobot);
        expect(
          _settingTileTrailing(
            'setting.appearance_tile',
            appearanceModeLabel(target),
          ),
          findsOneWidget,
        );

        // 'system' is the fallback branch — exercise it too.
        await _ensureAppearanceOpen(tester);
        await _selectRadio(tester, 'system');
        expect(_appThemeMode(tester), ThemeMode.system);
      } finally {
        await _ensureAppearanceOpen(tester);
        final origValue = switch (original) {
          ThemeMode.dark => 'dark',
          ThemeMode.light => 'light',
          ThemeMode.system => 'system',
        };
        await _selectRadio(tester, origValue);
        await appRobot.resetToRoot();
      }
    });

    testWidgets('vpn settings tile opens the vpn settings screen', (
      tester,
    ) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openSettings();
      try {
        await tester.tap(find.byKey(const Key('setting.vpn_setting_tile')));
        await WidgetWaitUtils.waitForFinder(
          tester,
          find.byKey(const Key('vpn_setting.list')),
          timeout: const Duration(seconds: 15),
          reason: 'VPN settings screen did not open',
        );
      } finally {
        await appRobot.resetToRoot();
      }
    });

    testWidgets('shows sign-in or account, never both', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openSettings();
      try {
        final signIn = _tileWithLabel('sign_in'.i18n);
        final account = _tileWithLabel('account'.i18n);
        expect(
          signIn != account,
          isTrue,
          reason:
              'Exactly one of the sign-in / account tiles must be visible '
              '(signIn=$signIn, account=$account)',
        );
      } finally {
        await appRobot.resetToRoot();
      }
    });
  });
}

/// Radio for [value] — the language and appearance lists both use
/// `AppRadioButton<String>` keyed by option value, so finders stay
/// locale-independent.
Finder _radio(String value) => find.byWidgetPredicate(
  (widget) => widget is AppRadioButton<String> && widget.value == value,
);

bool _isRadioSelected(WidgetTester tester, String value) {
  final radio = tester.widget<AppRadioButton<String>>(_radio(value));
  return radio.groupValue == value;
}

Future<void> _selectRadio(WidgetTester tester, String value) async {
  await tester.ensureVisible(_radio(value));
  await tester.tap(_radio(value));
  await tester.pumpAndSettle();
}

ThemeMode _appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ??
    ThemeMode.system;

/// The trailing [text] inside the settings tile with [tileKey].
Finder _settingTileTrailing(String tileKey, String text) =>
    find.descendant(of: find.byKey(Key(tileKey)), matching: find.text(text));

bool _tileWithLabel(String label) => find
    .byWidgetPredicate((widget) => widget is AppTile && widget.label == label)
    .evaluate()
    .isNotEmpty;

/// Appearance shows as a bottom sheet on mobile (closes on select) and a
/// pushed screen on desktop (stays open); normalize back to Settings.
Future<void> _ensureOnSettings(AppRobot appRobot) async {
  if (_appearanceList.evaluate().isNotEmpty) {
    await appRobot.goBack();
  }
}

/// Reopens the appearance options from Settings if they aren't showing.
Future<void> _ensureAppearanceOpen(WidgetTester tester) async {
  if (_appearanceList.evaluate().isNotEmpty) {
    return;
  }
  await tester.tap(find.byKey(const Key('setting.appearance_tile')));
  await WidgetWaitUtils.waitForFinder(
    tester,
    _appearanceList,
    timeout: const Duration(seconds: 10),
    reason: 'Appearance options did not reopen',
  );
}

