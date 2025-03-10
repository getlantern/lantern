import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/features/language/language_notifier.dart';

import 'core/common/common.dart';
import 'core/services/injection_container.dart';

final globalRouter = sl<AppRouter>();

class LanternApp extends HookConsumerWidget {
  const LanternApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageNotifierProvider);
    Localization.defaultLocale = locale.toString();
    final size = MediaQuery.of(context).size;
    appLogger.debug('MediaQuery: Size ${size}');
    return ScreenUtilInit(
      designSize: PlatformUtils.isDesktop() ? desktopWindowSize : mobileSize,
      minTextAdapt: true,
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
          routerConfig: globalRouter.config(),
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
