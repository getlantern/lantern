import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stealth direct-connection defaults are valid package names', () async {
    final raw = await File(
      'assets/stealth/default_exclusions.json',
    ).readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;

    expect(decoded['schema_version'], 1);
    expect(decoded['source'], isA<Map<String, Object?>>());

    final defaults = decoded['defaults'] as List<Object?>;
    expect(defaults, isNotEmpty);

    final packageNames = <String>[];
    final packageNamePattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

    for (final entry in defaults.cast<Map<String, Object?>>()) {
      final packageName = entry['package_name'] as String;
      packageNames.add(packageName);

      expect(packageName, packageName.toLowerCase());
      expect(packageNamePattern.hasMatch(packageName), isTrue);
      expect(entry['display_name'], isA<String>());
      expect(entry['reason_flags'], isA<List<Object?>>());
      expect(entry['source'], 'rks');
    }

    expect(packageNames.toSet(), hasLength(packageNames.length));
    expect(packageNames, contains('com.vkontakte.android'));
    expect(packageNames, contains('ru.sberbankmobile'));
    expect(packageNames, contains('ru.vtb24.mobilebanking.android'));
    expect(packageNames, contains('com.yandex.browser'));
  });
}
