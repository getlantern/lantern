import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/core/router/router.dart';
import 'core/common/common.dart';
import 'core/services/injection_container.dart';


final globalRouter = sl<AppRouter>();

class LanternApp extends StatelessWidget {
  const LanternApp({super.key});

  @override
  Widget build(BuildContext context) {
    print("Build called");
    Locale locale = PlatformDispatcher.instance.locale;
    AppDB.set<String>('locale', locale.languageCode);
    return I18n(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: locale,
        theme: AppTheme.appTheme(),
        themeMode: ThemeMode.light,
        darkTheme: AppTheme.darkTheme(),
        supportedLocales: languages
            .map((lang) => Locale(lang.split('_').first, lang.split('_').last))
            .toList(),
        // List of supported languages
        routerConfig: globalRouter.config(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  String _getLocaleBasedFont(Locale locale) {
    if (locale.languageCode == 'fa' ||
        locale.languageCode == 'ur' ||
        locale.languageCode == 'eg') {
      return AppFontFamily.semim.fontFamily; // Farsi font
    } else {
      return AppFontFamily
          .roboto.fontFamily; // Default font for other languages
    }
  }
}

// This enum is used to manage the font families used in the application
enum AppFontFamily {
  semim('Samim'),
  roboto('Roboto');

  // the actual string value (the font family name) to each enum value
  const AppFontFamily(this.fontFamily);

  final String fontFamily;
}
