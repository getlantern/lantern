import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/router/tv_route_builder.dart';

void main() {
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
