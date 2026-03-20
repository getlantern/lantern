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
  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;

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
    _deepLinkSubscription = appLinks.uriLinkStream.listen(_handleDeepLinkUri);
  }

  void _handleDeepLinkUri(Uri uri) {
    if (!context.mounted) return;
    final safeLogUri = uri.replace(query: '').toString();

    // Deduplicate: on cold start macOS may deliver the same URI via multiple
    // OS callbacks (URL scheme + NSAppleEventManager), causing a double push.
    final now = DateTime.now();
    if (_lastHandledUri == uri &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(seconds: 3)) {
      appLogger.debug("DeepLink deduplicated (already handled): $safeLogUri");
      return;
    }
    _lastHandledUri = uri;
    _lastHandledTime = now;

    appLogger.debug("DeepLink received: $safeLogUri");
    final path = uri.path;

    if (path.startsWith('/report-issue') ||
        (uri.scheme == 'lantern' && uri.host == 'report-issue')) {
      final queryParams = uri.queryParameters;
      final foundType = queryParams.containsKey('type');
      final fragment = uri.fragment;
      final hasFragment = fragment.isNotEmpty;
      appLogger.debug(
        "DeepLink report-issue: hasFragment=$hasFragment, foundType=$foundType, fragment=${hasFragment ? fragment : 'N/A'}, type=${queryParams['type'] ?? 'N/A'}",
      );
      if (hasFragment && foundType) {
        _pushWithHome(
          ReportIssue(description: '#$fragment', type: queryParams['type']),
        );
      } else if (hasFragment) {
        _pushWithHome(ReportIssue(description: '#$fragment'));
      } else if (foundType) {
        _pushWithHome(ReportIssue(type: queryParams['type']));
      } else {
        _pushWithHome(ReportIssue());
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
        appLogger.debug(
          "DeepLink private-server: missing or invalid exp param",
        );
        context.showSnackBar('invalid_deep_link'.i18n);
        return;
      }
      final expired = DateTime.fromMillisecondsSinceEpoch(expiration * 1000);
      appLogger.debug(
        "DeepLink private-server: exp=$expired, now=${DateTime.now()}, expired=${expired.isBefore(DateTime.now())}",
      );
      if (expired.isBefore(DateTime.now())) {
        AppDialog.dialog(
          context: context,
          title: 'expired'.i18n,
          content: 'deep_link_expired'.i18n,
        );
        return;
      }
      appLogger.debug(
        "DeepLink private-server: navigating to JoinPrivateServer",
      );
      _pushWithHome(JoinPrivateServer(deepLinkData: data));
    }
  }

  /// Pushes [route] on the current stack when the app is in the foreground
  /// (Home already loaded). On a cold start the router stack is empty, so we
  /// seed it with Home first to ensure the user always has a back button.
  void _pushWithHome(PageRouteInfo route) {
    final stack = appRouter.stack;
    // Guard against double-push: if the same route is already on top, skip.
    if (stack.isNotEmpty && stack.last.name == route.routeName) {
      appLogger.debug("Route ${route.routeName} already on top, skipping push");
      return;
    }
    final homeInStack = stack.any((r) => r.name == Home.name);
    if (homeInStack) {
      appLogger.debug("Pushing route $route on top of Home");
      appRouter.push(route);
    } else {
      appLogger.debug(
        "Home not in stack, replacing with Home and then pushing $route",
      );
      appRouter.replaceAll([Home(), route]);
    }
  }

  String _buildPrivateServerAccessKey(Uri uri) {
    if (uri.scheme == 'https' &&
        (uri.host == 'lantern.io' || uri.host == 'www.lantern.io')) {
      final pathWithoutLeadingSlash = uri.path.startsWith('/')
          ? uri.path.substring(1)
          : uri.path;
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
      overlayWidgetBuilder: (_) => Center(child: LoadingIndicator()),
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
                    .map(
                      (lang) =>
                          Locale(lang.split('_').first, lang.split('_').last),
                    )
                    .toList(),
                // List of supported languages
                routerConfig: globalRouter.config(
                  deepLinkBuilder: (deepLink) {
                    return DeepLink
                        .defaultPath; // We handle deep links manually, so return null to use the default route
                  },
                  navigatorObservers: () => [routeObserver],
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
