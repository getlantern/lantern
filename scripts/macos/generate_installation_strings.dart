// Xcode runs this at build time to turn the app's Transifex catalogs into native
// .strings files for the installation dialog, which appears before Flutter starts.
import 'dart:convert';
import 'dart:io';

import 'package:gettext_parser/gettext_parser.dart' as gettext;

const installationKeys = [
  'macos_installation_use_finder',
  'macos_installation_destination_exists',
  'macos_installation_title',
  'macos_installation_automatic',
  'macos_installation_move_relaunch',
  'macos_installation_replace',
  'macos_installation_manual',
  'macos_installation_show_applications',
  'macos_installation_progress',
  'macos_installation_please_wait',
  'macos_installation_open',
  'macos_installation_recovery',
  'quit',
];

Map<String, String> readCatalog(String source) {
  final entries = gettext.po.parse(source)['translations'][''] as Map;
  return {
    for (final key in installationKeys)
      if (entries[key] case final Map entry)
        if (!(entry['comments']?['flag'] as String? ?? '')
            .split(RegExp(r'[,\s]+'))
            .contains('fuzzy'))
          if (entry['msgstr'] case [final String value])
            if (value.trim().isNotEmpty) key: value,
  };
}

Set<String> placeholders(String value) => RegExp(
  r'\{\w+\}',
).allMatches(value).map((match) => match.group(0)!).toSet();

// Fall back to English if a translation is missing or changes the placeholders.
Map<String, String> withFallback(
  Map<String, String> english,
  Map<String, String> translated,
) => english.map((key, fallback) {
  final value = translated[key];
  final expected = placeholders(fallback);
  final actual = value == null ? <String>{} : placeholders(value);
  final valid =
      value != null &&
      expected.length == actual.length &&
      expected.containsAll(actual);
  return MapEntry(key, valid ? value : fallback);
});

String appleLocale(String name) {
  final parts = name.replaceAll('_', '-').split('-');
  return [
    parts.first.toLowerCase(),
    for (final part in parts.skip(1))
      if (part.length == 2)
        part.toUpperCase()
      else if (part.length == 4)
        '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}'
      else
        part,
  ].join('-');
}

void generateInstallationStrings(Directory catalogs, Directory resources) {
  final english = readCatalog(
    File('${catalogs.path}/en.po').readAsStringSync(),
  );
  final missing = installationKeys.where((key) => !english.containsKey(key));
  if (missing.isNotEmpty) {
    throw FormatException(
      'Missing English installation strings: ${missing.join(', ')}',
    );
  }
  final files =
      catalogs
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.po'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final outputs = <String>{};
  for (final file in files) {
    final name = file.uri.pathSegments.last.replaceFirst(RegExp(r'\.po$'), '');
    final locale = appleLocale(name);
    final strings = withFallback(english, readCatalog(file.readAsStringSync()));
    final output = File(
      '${resources.path}/$locale.lproj/AppInstallation.strings',
    );
    output.parent.createSync(recursive: true);
    final content = strings.entries
        .map(
          (entry) => '${jsonEncode(entry.key)} = ${jsonEncode(entry.value)};\n',
        )
        .join();
    if (!output.existsSync() || output.readAsStringSync() != content) {
      output.writeAsStringSync(content);
    }
    outputs.add(output.path);
  }
  // Remove only this table when a locale is removed from Transifex.
  for (final directory in resources.listSync().whereType<Directory>()) {
    if (!directory.path.endsWith('.lproj')) continue;
    final old = File('${directory.path}/AppInstallation.strings');
    if (old.existsSync() && !outputs.contains(old.path)) old.deleteSync();
  }
}

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart generate_installation_strings.dart <locales> <resources>',
    );
    exitCode = 64;
    return;
  }
  generateInstallationStrings(Directory(arguments[0]), Directory(arguments[1]));
}
