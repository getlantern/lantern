import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/core/router/router.dart';
import 'core/common/common.dart';
import 'core/services/injection_container.dart';

class LanternApp extends StatelessWidget {
  const LanternApp({super.key});

  @override
  Widget build(BuildContext context) {
    Locale locale = PlatformDispatcher.instance.locale;

    final _router = GoRouter(
      routes: $appRoutes,
    );

    return ScreenUtilInit(
      child: I18n(
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
              .map(
                  (lang) => Locale(lang.split('_').first, lang.split('_').last))
              .toList(),
          // List of supported languages
          routerConfig: _router,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}
