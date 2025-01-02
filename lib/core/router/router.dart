import 'package:auto_route/auto_route.dart';

import 'package:lantern/core/router/router.gr.dart';

@AutoRouterConfig(
  replaceInRouteName: 'Page,Route,Screen',
)
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();
  @override
  final List<AutoRoute> routes = [
    AutoRoute(
      path: '/',
      page: Home.page,
    ),
  ];
}
