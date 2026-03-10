import 'dart:async';
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
  StreamSubscription<Uri>? _deepLinkSubscription;

  // Set of URI strings already dispatched to _handleDeepLinkUri this session.
  // Using a Set (not a single URI) correctly deduplicates across all call sites
  // (stream, getInitialLink) without any timing dependency.
  // Instance field — cleared on app resume so the same link can be reused
  // after the user backgrounds and re-opens the app.

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
    _deepLinkSubscription?.cancel();
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

    // app_links 7.x delivers the cold-start URI via uriLinkStream on all
    // platforms (including when the app was fully closed), so getInitialLink()
    // is not needed and would cause a double push.
    _deepLinkSubscription = appLinks.uriLinkStream.listen(_handleDeepLinkUri);
  }

  void _handleDeepLinkUri(Uri uri) {
    if (!context.mounted) return;
    final safeLogUri = uri.replace(query: '').toString();
    appLogger.debug("DeepLink received: $safeLogUri");

    // Normalize: custom scheme lantern://open/path → treat as /path
    final path = uri.path;

    if (path.startsWith('/report-issue') ||
        (uri.scheme == 'lantern' && uri.host == 'report-issue')) {
      final pathUrl = uri.toString();
      final queryParams = uri.queryParameters;
      final segment = pathUrl.split('#');
      if (segment.length >= 2) {
        appRouter.push(ReportIssue(
            description: '#${segment[1]}', type: queryParams['type']));
      } else if (queryParams.isNotEmpty) {
        appRouter.push(ReportIssue(type: queryParams['type']));
      } else {
        appRouter.push(ReportIssue(),);
      }
    } else if (path.startsWith('/auth') ||
        (uri.scheme == 'lantern' && uri.host == 'auth')) {
      if (uri.queryParameters.containsKey('token')) {
        sl<DeepLinkCallbackManager>().handleDeepLink(uri.queryParameters);
      }
    } else if (path.startsWith('/private-server') ||
        (uri.scheme == 'lantern' && uri.host == 'private-server')) {
      final data = Map.of(uri.queryParameters);
      appLogger.debug("DeepLink private-server params: ${data.keys.toList()}");
      data['accessKey'] = _buildPrivateServerAccessKey(uri);
      final expiration = int.tryParse((data['exp'] ?? '').toString());
      if (expiration == null) {
        appLogger
            .debug("DeepLink private-server: missing or invalid exp param");
        context.showSnackBar('invalid_deep_link'.i18n);
        return;
      }
      final expired = DateTime.fromMillisecondsSinceEpoch(expiration * 1000);
      appLogger.debug(
          "DeepLink private-server: exp=$expired, now=${DateTime.now()}, expired=${expired.isBefore(DateTime.now())}");
      if (expired.isBefore(DateTime.now())) {
        AppDialog.dialog(
          context: context,
          title: 'expired'.i18n,
          content: 'deep_link_expired'.i18n,
        );
        return;
      }
      appLogger
          .debug("DeepLink private-server: navigating to JoinPrivateServer");
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
    if (uri.scheme == 'lantern') {
      // lantern://private-server?key=value → lantern//private-server?key=value
      var accessKey = 'lantern//${uri.host}';
      if (uri.hasQuery) {
        accessKey += '?${uri.query}';
      }
      return accessKey;
    }
    return uri.toString();
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
                  // Always return default path so AutoRoute does not attempt
                  // to parse and navigate the deeplink URI itself. All deeplink
                  // navigation is handled exclusively by _handleDeepLinkUri
                  // (via getInitialLink / uriLinkStream). Without this,
                  // AutoRoute would push a matching route AND _handleDeepLinkUri
                  // would push it again, causing a double-push on cold start.
                  deepLinkBuilder: (_) => DeepLink.defaultPath,
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
