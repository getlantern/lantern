import 'dart:ui';

import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/utils/once.dart';

extension Localization on String {
  static String defaultLocale = 'en_us';
  static String locale = defaultLocale;

  static Translations translations =
      Translations.byLocale(defaultLocale.toBCP47());

  static Future<Translations> Function(
    Future<Translations> Function(),
  ) loadTranslationsOnce = once<Future<Translations>>();

  static Future<Translations> ensureInitialized() async {
    return loadTranslationsOnce(() {
      return GettextImporter()
          .fromAssetDirectory('assets/locales')
          .then((value) {
        translations += value;
        return translations;
      });
    });
  }

  static String get localeShort => locale.split('_')[0];

  String get languageTag => locale.replaceFirst('_', '-').toLowerCase();

  String doLocalize() => localize(this, translations, languageTag: languageTag);

  String get i18n => localize(this, translations, languageTag: languageTag);

  String fill(List<Object> params) => localizeFill(this, params);
}

extension StringExtensions on String {
  String toBCP47() {
    // Split the string by underscore or dash
    final parts = split(RegExp(r'[_-]'));

    if (parts.length > 1) {
      // Capitalize the region code (e.g., "us" -> "US")
      return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
    } else {
      // Return just the language code if no region code is present
      return parts[0].toLowerCase();
    }
  }
}
