import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/widgets/tv_frame.dart';
import 'package:lantern/core/widgets/tv_shell.dart';

import '../common/common.dart' show appRouter;

/// Screens that take the whole TV screen, without the logo-and-switch panel:
/// onboarding, purchase, sign-in and account flows, the private-server setup
/// forms, the QR scanner and developer mode. Forms laid out for the panel
/// (Report an Issue, Website split tunneling) stay in it.
const Set<String> tvFullScreenRoutes = {
  Onboarding.name,
  Plans.name,
  ChoosePaymentMethod.name,
  AppWebview.name,
  SignInEmail.name,
  SignInPassword.name,
  AddEmail.name,
  ConfirmEmail.name,
  CreatePassword.name,
  ResetPasswordEmail.name,
  ResetPassword.name,
  LanternProLicense.name,
  DeleteAccount.name,
  JoinPrivateServer.name,
  ManuallyServerSetup.name,
  PrivateServerAddBilling.name,
  PrivateServerDetails.name,
  QrCodeScanner.name,
  DeveloperMode.name,
};

/// Action Mode and proxy-invite screens have no entry points on TV and are
/// never rendered: a stale push of one returns to the screen under it, and a
/// launch straight into one (a deep link) lands on Home.
const Set<String> tvRedirectRoutes = {
  ActionModeSetting.name,
  HelpFriend.name,
  InviteShare.name,
  PersonalProxiesIntro.name,
};

/// Full-screen routes with their own TV layout across the whole screen,
/// instead of the centred phone-width column. Plans has one only with
/// payments; its license-only body keeps the column.
const Set<String> tvOwnLayoutRoutes = {
  if (AppBuildInfo.enablePayments) Plans.name,
};

const Duration tvRouteDuration = Duration(milliseconds: 200);

/// The TV shell's route: every screen is wrapped in [TvShell] unless it is
/// full screen. Page settings are forwarded so auto_route's page-to-route
/// pairing and the user-message route observer see the same flags as the
/// adaptive route they replace.
Route<T> tvRouteBuilder<T>(
  BuildContext context,
  Widget child,
  AutoRoutePage<T> page,
) {
  final name = page.routeData.name;
  final fullScreen = tvFullScreenRoutes.contains(name);
  final body = tvRedirectRoutes.contains(name) ? const _RedirectHome() : child;
  return PageRouteBuilder<T>(
    settings: page,
    fullscreenDialog: page.fullscreenDialog,
    maintainState: page.maintainState,
    opaque: page.opaque,
    transitionDuration: tvRouteDuration,
    reverseTransitionDuration: tvRouteDuration,
    // Full-screen routes keep today's centred phone-width column unless
    // they lay themselves out for the TV.
    pageBuilder: (context, _, _) => fullScreen
        ? TvFrame(
            enabled: !tvOwnLayoutRoutes.contains(name),
            background: Theme.of(context).scaffoldBackgroundColor,
            child: body,
          )
        : TvShell(routeName: name, child: body),
    // The shell fades only its screen panel, so the logo and switch hold
    // still from one screen to the next.
    transitionsBuilder: (_, animation, _, child) =>
        fullScreen ? FadeTransition(opacity: animation, child: child) : child,
  );
}

class _RedirectHome extends StatefulWidget {
  const _RedirectHome();

  @override
  State<_RedirectHome> createState() => _RedirectHomeState();
}

class _RedirectHomeState extends State<_RedirectHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A stale push over a real screen drops only itself; launched straight
      // into it, there is nothing underneath, so Home.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        appRouter.replaceAll([const Home()]);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
