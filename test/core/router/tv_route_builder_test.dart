import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/router/tv_route_builder.dart';
import 'package:lantern/core/utils/platform_utils.dart';

void main() {
  tearDown(() => PlatformUtils.debugTvShell = null);

  test('on TV the router builds every route through tvRouteBuilder', () {
    PlatformUtils.debugTvShell = true;
    final router = AppRouter();
    final type = router.defaultRouteType;
    expect(type, isA<CustomRouteType>());
    expect((type as CustomRouteType).customRouteBuilder, tvRouteBuilder);
    // The one route with its own type takes the same path on TV.
    final setting = router.routes.singleWhere((r) => r.path == '/setting');
    expect(setting, isNot(isA<CustomRoute>()));
  });

  test('elsewhere the router keeps the adaptive route and the slide', () {
    PlatformUtils.debugTvShell = false;
    final router = AppRouter();
    expect(router.defaultRouteType, isA<AdaptiveRouteType>());
    final setting = router.routes.singleWhere((r) => r.path == '/setting');
    expect(setting, isA<CustomRoute>());
  });

  test('Home and the converted screens render inside the shell', () {
    for (final name in [
      Home.name,
      Setting.name,
      ServerSelection.name,
      ReportIssue.name,
      WebsiteSplitTunneling.name,
    ]) {
      expect(tvFullScreenRoutes, isNot(contains(name)));
      expect(tvRedirectRoutes, isNot(contains(name)));
    }
  });

  test(
    'onboarding, purchase, sign-in and text entry take the whole screen',
    () {
      for (final name in [
        Onboarding.name,
        Plans.name,
        ChoosePaymentMethod.name,
        SignInEmail.name,
        DeleteAccount.name,
      ]) {
        expect(tvFullScreenRoutes, contains(name));
      }
    },
  );

  test('Action Mode and invite screens are sent back to Home', () {
    for (final name in [
      ActionModeSetting.name,
      HelpFriend.name,
      InviteShare.name,
      PersonalProxiesIntro.name,
    ]) {
      expect(tvRedirectRoutes, contains(name));
      expect(tvFullScreenRoutes, isNot(contains(name)));
    }
  });
}
