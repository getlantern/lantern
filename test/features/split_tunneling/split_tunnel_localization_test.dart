import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every locale includes split-tunnel labels and preserves placeholders',
    () {
      final entry = RegExp(r'msgid "([^"]+)"\nmsgstr ("[^\n]*")');
      final english = {
        for (final match in entry.allMatches(
          File('assets/locales/en.po').readAsStringSync(),
        ))
          if (match[1]!.startsWith('split_tunnel_') ||
              [
                'apps_using_vpn',
                'websites_using_vpn',
                'add_executable',
                'select_windows_executable',
                'unable_to_add_executable',
              ].contains(match[1]))
            match[1]!: jsonDecode(match[2]!) as String,
      };
      final placeholders = RegExp(r'%[sd]');
      expect(english.length, greaterThan(20));
      for (final file in Directory(
        'assets/locales',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.po'))) {
        final translated = {
          for (final match in entry.allMatches(file.readAsStringSync()))
            match[1]!: jsonDecode(match[2]!) as String,
        };
        for (final message in english.entries) {
          final value = translated[message.key];
          expect(value, isNotNull, reason: '${file.path}: ${message.key}');
          expect(value, isNotEmpty, reason: '${file.path}: ${message.key}');
          expect(
            placeholders.allMatches(value!).map((m) => m[0]),
            placeholders.allMatches(message.value).map((m) => m[0]),
            reason: '${file.path}: ${message.key}',
          );
        }
      }
    },
  );
}
