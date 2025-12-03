import 'dart:collection';
import 'dart:convert';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/utils/once.dart';
import 'package:flutter/services.dart';

extension Localization on String {
  static String defaultLocale = 'en_US';

  static Translations translations =
      Translations.byLocale(defaultLocale.toBCP47());

  static Future<Translations> Function(
    Future<Translations> Function(),
  ) loadTranslationsOnce = once<Future<Translations>>();

  static Future<void> loadTranslations() async {
    translations += await fromAssetDirectory("assets/locales");
  }

  String get i18n =>
      localize(this, translations, languageTag: defaultLocale.toBCP47());

  String plural(String value) => localizePlural(value, this, translations);

  String fill(List<Object> params) => localizeFill(this, params);

  String args(Map<Object, Object> params) =>
      localizeArgs(this, translations, params);
}

Future<Map<String, Map<String, String>>> fromAssetDirectory(String dir) async {
  final manifestContent = await AssetManifest.loadFromAssetBundle(rootBundle);
  Map<String, Map<String, String>> translations = HashMap();

  for (String path in manifestContent.listAssets()) {
    if (!path.startsWith(dir)) continue;
    var fileName = path.split("/").last;
    if (!fileName.endsWith(".po")) {
      continue;
    }
    var languageCode = fileName.split(".")[0];
    translations
        .addAll(await GettextImporter().fromAssetFile(languageCode, path));
  }

  return translations;
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
