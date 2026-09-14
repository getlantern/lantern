import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/macos/generate_installation_strings.dart';

void main() {
  test('reads multiline PO strings, ignores fuzzy and empty translations', () {
    final strings = readCatalog(r'''
msgid "macos_installation_title"
msgstr ""
"Déplacer {appName} "
"dans Applications"

#, fuzzy
msgid "quit"
msgstr "Quitter"

msgid "macos_installation_progress"
msgstr ""

msgid "macos_installation_recovery"
msgstr "{error}\n\nOuvrir \"{appName}\""
''');
    expect(strings, {
      'macos_installation_title': 'Déplacer {appName} dans Applications',
      'macos_installation_recovery': '{error}\n\nOuvrir "{appName}"',
    });
  });

  test('falls back per key if a translation loses or adds a placeholder', () {
    const english = {
      'missing': 'English',
      'lost': 'Move {appName}',
      'extra': 'Move {appName}',
      'reordered': '{error}: Open {appName}',
      'valid': 'Quit',
    };
    expect(
      withFallback(english, {
        'lost': 'Déplacer',
        'extra': 'Déplacer {appName} {unknown}',
        'reordered': 'Ouvrir {appName}: {error}',
        'valid': 'Quitter',
      }),
      {
        ...english,
        'reordered': 'Ouvrir {appName}: {error}',
        'valid': 'Quitter',
      },
    );
  });

  test('normalizes Transifex region and script codes for Apple', () {
    expect(appleLocale('pt_BR'), 'pt-BR');
    expect(appleLocale('es-cu'), 'es-CU');
    expect(appleLocale('ur-in'), 'ur-IN');
    expect(appleLocale('zh-Hans'), 'zh-Hans');
    expect(appleLocale('fa'), 'fa');
  });

  test('generates every native table from the checked-in catalogs', () {
    final output = Directory.systemTemp.createTempSync('installation-strings-');
    addTearDown(() => output.deleteSync(recursive: true));
    final stale = File('${output.path}/zz.lproj/AppInstallation.strings');
    stale.parent.createSync();
    stale.writeAsStringSync('stale');
    final unrelated = File('${stale.parent.path}/Unrelated.strings');
    unrelated.writeAsStringSync('keep');
    final catalogs = Directory('assets/locales');
    generateInstallationStrings(catalogs, output);
    expect(stale.existsSync(), isFalse);
    expect(unrelated.readAsStringSync(), 'keep');
    for (final file in catalogs.listSync().whereType<File>()) {
      if (!file.path.endsWith('.po')) continue;
      final locale = appleLocale(
        file.uri.pathSegments.last.replaceAll('.po', ''),
      );
      final table = File(
        '${output.path}/$locale.lproj/AppInstallation.strings',
      );
      expect(table.existsSync(), isTrue, reason: locale);
      for (final key in installationKeys) {
        expect(table.readAsStringSync(), contains('"$key" = '), reason: locale);
      }
    }
    final french = File('${output.path}/fr.lproj/AppInstallation.strings');
    expect(french.readAsStringSync(), contains('"quit" = "Quitter";'));
    final before = french.lastModifiedSync();
    generateInstallationStrings(catalogs, output);
    expect(french.lastModifiedSync(), before);
  });

  test('missing source strings fail the build', () {
    final root = Directory.systemTemp.createTempSync('installation-strings-');
    addTearDown(() => root.deleteSync(recursive: true));
    File(
      '${root.path}/en.po',
    ).writeAsStringSync('msgid "quit"\nmsgstr "Quit"\n');
    expect(
      () => generateInstallationStrings(root, Directory('${root.path}/out')),
      throwsFormatException,
    );
  });
}
