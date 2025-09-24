import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/utils/once.dart';

extension Localization on String {
  static String defaultLocale = 'en_US';

  static Translations translations =
      Translations.byLocale(defaultLocale.toBCP47());

  static Future<Translations> Function(
    Future<Translations> Function(),
  ) loadTranslationsOnce = once<Future<Translations>>();

  static Future<void> loadTranslations() async {
    translations +=
        await GettextImporter().fromAssetDirectory("assets/locales");
  }

  String get i18n =>
      localize(this, translations, languageTag: defaultLocale.toBCP47());

  String plural(String value) => localizePlural(value, this, translations);

  String fill(List<Object> params) => localizeFill(this, params);

  String args(Map<Object, Object> params) =>
      localizeArgs(this, translations, params);
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
