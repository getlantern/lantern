import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';

// Every locale file must load through the same parser the app uses at runtime
// and stay consistent with en.po, so a bad write by the translation tool fails
// here instead of on a user's phone.
void main() {
  final dir = Directory('assets/locales');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.po'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final placeholder = RegExp(r'%(?:\d+\$)?[sd]');
  List<String> holes(String s) =>
      placeholder.allMatches(s).map((m) => m.group(0)!).toList();

  late Map<String, String> en;

  setUpAll(() async {
    final loaded = await GettextImporter()
        .fromString('en', File('assets/locales/en.po').readAsStringSync());
    en = loaded['en']!;
  });

  test('en.po loads and is not empty', () {
    expect(en.length, greaterThan(400));
  });

  for (final file in files) {
    final code = file.uri.pathSegments.last.split('.').first;
    if (code == 'en') continue;

    test('$code.po loads and agrees with en.po', () async {
      final loaded =
          await GettextImporter().fromString(code, file.readAsStringSync());
      final strings = loaded[code]!;
      expect(strings, isNotEmpty, reason: '$code parsed to nothing');

      final stale = strings.keys.where((k) => !en.containsKey(k)).toList();
      expect(stale, isEmpty, reason: '$code has keys missing from en.po');

      for (final entry in strings.entries) {
        final source = en[entry.key]!;
        expect(holes(entry.value), holes(source),
            reason: '$code "${entry.key}" placeholders differ');
        expect('\n'.allMatches(entry.value).length,
            '\n'.allMatches(source).length,
            reason: '$code "${entry.key}" line break count differs');
        expect(entry.value.startsWith(' '), source.startsWith(' '),
            reason: '$code "${entry.key}" leading space differs');
        expect(entry.value.endsWith(' '), source.endsWith(' '),
            reason: '$code "${entry.key}" trailing space differs');
      }
    });
  }
}
