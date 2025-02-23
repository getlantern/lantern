// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $homeRoute,
    ];

RouteBase get $homeRoute => GoRouteData.$route(
      path: '/',
      factory: $HomeRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: '/',
          factory: $HomeRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/setting',
          factory: $SettingRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/language',
          factory: $LanguageRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/report-issue',
          factory: $ReportIssueRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/download',
          factory: $DownloadLinksRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/invite-friends',
          factory: $InviteFriendsRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/vpn-setting',
          factory: $VPNSettingRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/account',
          factory: $AccountRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: '/delete-account',
          factory: $DeleteAccountRouteExtension._fromState,
        ),
      ],
    );

extension $HomeRouteExtension on HomeRoute {
  static HomeRoute _fromState(GoRouterState state) => HomeRoute();

  String get location => GoRouteData.$location(
        '/',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingRouteExtension on SettingRoute {
  static SettingRoute _fromState(GoRouterState state) => SettingRoute();

  String get location => GoRouteData.$location(
        '/setting',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $LanguageRouteExtension on LanguageRoute {
  static LanguageRoute _fromState(GoRouterState state) => LanguageRoute();

  String get location => GoRouteData.$location(
        '/language',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ReportIssueRouteExtension on ReportIssueRoute {
  static ReportIssueRoute _fromState(GoRouterState state) => ReportIssueRoute();

  String get location => GoRouteData.$location(
        '/report-issue',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $DownloadLinksRouteExtension on DownloadLinksRoute {
  static DownloadLinksRoute _fromState(GoRouterState state) =>
      DownloadLinksRoute();

  String get location => GoRouteData.$location(
        '/download',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $InviteFriendsRouteExtension on InviteFriendsRoute {
  static InviteFriendsRoute _fromState(GoRouterState state) =>
      InviteFriendsRoute();

  String get location => GoRouteData.$location(
        '/invite-friends',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $VPNSettingRouteExtension on VPNSettingRoute {
  static VPNSettingRoute _fromState(GoRouterState state) => VPNSettingRoute();

  String get location => GoRouteData.$location(
        '/vpn-setting',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AccountRouteExtension on AccountRoute {
  static AccountRoute _fromState(GoRouterState state) => AccountRoute();

  String get location => GoRouteData.$location(
        '/account',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $DeleteAccountRouteExtension on DeleteAccountRoute {
  static DeleteAccountRoute _fromState(GoRouterState state) =>
      DeleteAccountRoute();

  String get location => GoRouteData.$location(
        '/delete-account',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}
