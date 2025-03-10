import 'package:app_links/app_links.dart';
import 'package:auto_route/auto_route.dart';
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

class LanternApp extends StatefulHookConsumerWidget {
  const LanternApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _LanternAppState();
}

class _LanternAppState extends ConsumerState<LanternApp> {
  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  Future<void> initDeepLinks() async {
    final appLinks = AppLinks();
    // Handle link when app is in warm state (front or background)
    appLinks.uriLinkStream.listen((Uri uri) {
      if (context.mounted) {
        if (uri.path.startsWith('/report-issue')) {
          final pathUrl = uri.toString();
          final segment = pathUrl.split('#');
          if (segment.length >= 2) {
            globalRouter.push(ReportIssue(description: '#${segment[1]}'));
          } else {
            globalRouter.push(ReportIssue());
          }
        }
      }
    });
  }

  DeepLink navigateToDeepLink(PlatformDeepLink deepLink) {
    appLogger
        .debug("DeepLink configuration: ${deepLink.configuration.toString()}");
    if (deepLink.path.toLowerCase().startsWith('/report-issue')) {
      appLogger.debug("DeepLink uri: ${deepLink.uri.toString()}");
      final pathUrl = deepLink.uri.toString();
      final segment = pathUrl.split('#');
      //If deeplink doesn't have data it should send to report issue with empty description'
      if (segment.length >= 2) {
        final description = segment[1];
        return DeepLink(
            [const Home(), ReportIssue(description: '#$description')]);
      }
      return DeepLink([const Home(), ReportIssue()]);
    } else {
      return DeepLink.defaultPath;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          routerConfig: globalRouter.config(
            deepLinkBuilder: navigateToDeepLink,
          ),
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
