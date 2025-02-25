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
      page: NewHome.page,
    ),
    AutoRoute(
      path: '/setting',
      page: Setting.page,
    ),
    AutoRoute(
      path: '/language',
      page: Language.page,
    ),
    AutoRoute(
      path: '/report-issue',
      page: ReportIssue.page,
    ),
    AutoRoute(
      path: '/report-issue',
      page: DownloadLinks.page,
    ),
    AutoRoute(
      path: '/invite-friends',
      page: InviteFriends.page,
    ),
    AutoRoute(
      path: '/vpn-setting',
      page: VPNSetting.page,
    ),
    AutoRoute(
      path: '/account',
      page: Account.page,
    ),
    AutoRoute(
      path: '/delete-account',
      page: DeleteAccount.page,
    ),
    AutoRoute(
      path: '/support',
      page: Support.page,
    ),
    AutoRoute(
      path: '/follow-us',
      page: FollowUs.page,
    ),
  ];
}
