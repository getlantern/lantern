import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/router/router.dart';

final globalRouter = AppRouter();

class LanternApp extends StatelessWidget {
  const LanternApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Get the current device locale here
        Locale locale = Localizations.localeOf(context);
        return Theme(
          data: ThemeData(
            useMaterial3: false,
            fontFamily: _getLocaleBasedFont(locale),
            brightness: Brightness.light,
            primarySwatch: Colors.grey,
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle.dark,
            ),
            colorScheme: ColorScheme.fromSwatch().copyWith(
              secondary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
      routerConfig: globalRouter.config(),
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
