import 'package:auto_route/auto_route.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/utils/route_utils.dart';

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
    CustomRoute(
      path: '/setting',
      page: Setting.page,
      transitionsBuilder: slideLeftToRight,
      duration: Duration(milliseconds: 320),
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
      path: '/logs',
      page: Logs.page,
    ),
    AutoRoute(
      path: '/support',
      page: Support.page,
    ),
    AutoRoute(
      path: '/follow-us',
      page: FollowUs.page,
    ),
    AutoRoute(
      path: '/server-selection',
      page: ServerSelection.page,
    ),
    AutoRoute(
      path: '/plans',
      page: Plans.page,
    ),
    AutoRoute(
      path: '/add-email',
      page: AddEmail.page,
    ),
    AutoRoute(
      path: '/confirm-email',
      page: ConfirmEmail.page,
    ),
    AutoRoute(
      path: '/create-password',
      page: CreatePassword.page,
    ),
    AutoRoute(
      path: '/choose-payment-method',
      page: ChoosePaymentMethod.page,
    ),
    AutoRoute(
      path: '/sign-in-email',
      page: SignInEmail.page,
    ),
    AutoRoute(
      path: '/sign-in-password',
      page: SignInPassword.page,
    ),
    AutoRoute(
      path: '/reset-password-email',
      page: ResetPasswordEmail.page,
    ),
    AutoRoute(
      path: '/reset-password',
      page: ResetPassword.page,
    ),
    AutoRoute(
      path: '/activation-code',
      page: ActivationCode.page,
    ),
    AutoRoute(
      path: '/device-limit-reached',
      page: DeviceLimitReached.page,
    ),
    AutoRoute(
      path: '/app-webview',
      page: AppWebview.page,
      fullscreenDialog: true,
    ),
    AutoRoute(
      path: '/split-tunneling',
      page: SplitTunneling.page,
    ),
    AutoRoute(
      path: '/split-tunneling-info',
      page: SplitTunnelingInfo.page,
    ),
    AutoRoute(
      path: '/default-bypass-lists',
      page: DefaultBypassLists.page,
    ),
    AutoRoute(
      path: '/apps-split-tunneling',
      page: AppsSplitTunneling.page,
    ),
    AutoRoute(
      path: '/website-split-tunneling',
      page: WebsiteSplitTunneling.page,
    ),
    AutoRoute(
      path: '/private-server-setup',
      page: PrivateServerSetup.page,
    ),
    AutoRoute(
      path: '/private-server-location',
      page: PrivateServerLocation.page,
      fullscreenDialog: true,
    ),
    AutoRoute(
      path: '/private-server-details',
      page: PrivateServerDetails.page,
    ),
    AutoRoute(
      path: '/private-server-deploy',
      page: PrivateServerDeploy.page,
    ),
    AutoRoute(
      path: '/manual-server-setup',
      page: ManuallyServerSetup.page,
    ),
    AutoRoute(
      path: '/join-private-server',
      page: JoinPrivateServer.page,
    ),
    AutoRoute(
      path: '/manage-private-server',
      page: ManagePrivateServer.page,
    ),
    AutoRoute(
      path: '/add-billing-private-server',
      page: PrivateServerAddBilling.page,
    ),
    AutoRoute(
      path: '/qr-scanner',
      page: QrCodeScanner.page,
    ),
    AutoRoute(
      path: '/system-extension-dialog',
      page: MacOSExtensionDialog.page,
      fullscreenDialog: true,
    ),
  ];
}
