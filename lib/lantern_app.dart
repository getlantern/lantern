import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/window/window_wrapper.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

import 'core/common/common.dart';
import 'core/services/injection_container.dart';
import 'core/utils/deeplink_utils.dart' show DeepLinkCallbackManager;
import 'features/system_tray/system_tray_wrapper.dart';

final globalRouter = sl<AppRouter>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class LanternApp extends StatefulHookConsumerWidget {
  const LanternApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _LanternAppState();
}

class _LanternAppState extends ConsumerState<LanternApp>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initDeepLinks();
    initLifecycleListener();
  }

  void initLifecycleListener() {
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        appLogger.info("Exit requested");
        await ref
            .read(lanternServiceProvider)
            .stopVPN()
            .timeout(const Duration(seconds: 5));
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    ref
        .read(appSettingProvider.notifier)
        .syncDesktopBrightnessFromCurrentTheme();
  }

  Future<void> initDeepLinks() async {
    final appLinks = AppLinks();

    // Cold start: defer until first frame so navigation/snackbars are safe.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final initialUri = await appLinks.getInitialLink();
        if (!mounted) return;
        if (initialUri != null) {
          _handleDeepLinkUri(initialUri);
        }
      } catch (e) {
        appLogger.error("Error getting initial deep link: $e");
      }
    });

    // Warm state: handle links when app is already running
    appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLinkUri(uri);
    });
  }

  void _handleDeepLinkUri(Uri uri) {
    if (!context.mounted) return;
    final safeLogUri = uri.replace(query: '').toString();
    appLogger.debug("DeepLink received: $safeLogUri");

    // Normalize: custom scheme lantern://open/path → treat as /path
    final path = uri.path;

    if (path.startsWith('/report-issue')) {
      final pathUrl = uri.toString();
      final queryParams = uri.queryParameters;
      final segment = pathUrl.split('#');
      if (segment.length >= 2) {
        globalRouter.push(ReportIssue(
            description: '#${segment[1]}', type: queryParams['type']));
      } else if (queryParams.isNotEmpty) {
        globalRouter.push(ReportIssue(type: queryParams['type']));
      } else {
        globalRouter.push(ReportIssue());
      }
    } else if (path.startsWith('/auth')) {
      if (uri.query.startsWith('token=')) {
        sl<DeepLinkCallbackManager>().handleDeepLink(uri.queryParameters);
      }
    } else if (path.startsWith('/private-server')) {
      final data = Map.of(uri.queryParameters);
      data['accessKey'] = _buildPrivateServerAccessKey(uri);
      final expiration = int.tryParse((data['exp'] ?? '').toString());
      if (expiration == null) {
        context.showSnackBar('invalid_deep_link'.i18n);
        return;
      }
      final expired = DateTime.fromMillisecondsSinceEpoch(expiration * 1000);
      if (expired.isBefore(DateTime.now())) {
        appLogger.debug("DeepLink expired: $expired");
        context.showSnackBar('deep_link_expired'.i18n);
        return;
      }
      appRouter.push(JoinPrivateServer(deepLinkData: data));
    }
  }

  String _buildPrivateServerAccessKey(Uri uri) {
    if (uri.scheme == 'https' &&
        (uri.host == 'lantern.io' || uri.host == 'www.lantern.io')) {
      final pathWithoutLeadingSlash =
          uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      var accessKey = 'lantern//$pathWithoutLeadingSlash';
      if (uri.hasQuery) {
        accessKey += '?${uri.query}';
      }
      return accessKey;
    }
    return uri.toString();
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
        return DeepLink([Home(), ReportIssue(description: '#$description')]);
      }
      return DeepLink([Home(), ReportIssue()]);
    } else {
      return DeepLink.defaultPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSetting = ref.watch(appSettingProvider);
    final locale = appSetting.locale;
    Localization.defaultLocale = locale;
    return GlobalLoaderOverlay(
      overlayColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.5),
      overlayWidgetBuilder: (_) => Center(
        child: LoadingIndicator(),
      ),
      child: WindowWrapper(
        child: SystemTrayWrapper(
          child: ScreenUtilInit(
            ensureScreenSize: true,
            designSize: designSizeFor(context),
            minTextAdapt: true,
            child: I18n(
              initialLocale: locale.toLocale,
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              child: MaterialApp.router(
                locale: locale.toLocale,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.appTheme(),
                darkTheme: AppTheme.darkTheme(),
                themeMode: resolveThemeMode(appSetting.themeMode),
                supportedLocales: languages
                    .map((lang) =>
                        Locale(lang.split('_').first, lang.split('_').last))
                    .toList(),
                // List of supported languages
                routerConfig: globalRouter.config(
                  deepLinkBuilder: navigateToDeepLink,
                  navigatorObservers: () => [
                    routeObserver,
                  ],
                ),
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
