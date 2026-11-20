import 'package:lantern/core/utils/telemetry.dart';

/// Steps of the in-app checkout funnel, from the plans screen to the account
/// showing the purchase.
enum CheckoutEvent {
  plansViewed('checkout_plans_viewed'),
  methodsViewed('checkout_methods_viewed'),
  started('checkout_started'),
  redirectFailed('checkout_redirect_failed'),
  webviewClosed('checkout_webview_closed'),
  cancelled('checkout_cancelled'),
  confirmed('checkout_confirmed'),
  notConfirmed('checkout_not_confirmed');

  const CheckoutEvent(this.tag);

  final String tag;
}

void trackCheckout(
  CheckoutEvent event, [
  Map<String, Object?> properties = const {},
]) => logTelemetry(event.tag, properties);

/// How a checkout webview ended: true when it reached the completion URL,
/// false on the cancel URL, null when the user closed it.
String webviewOutcome(bool? result) => switch (result) {
  true => 'completed',
  false => 'cancelled',
  null => 'closed',
};

/// Properties for [CheckoutEvent.webviewClosed]. Pass [observable] false where
/// the app can't see the window close: on Linux the checkout opens in a
/// separate native window and returns at once.
Map<String, Object?> webviewClosedProperties(
  String provider,
  bool? result,
  Duration open, {
  required bool observable,
}) => {
  'provider': provider,
  'outcome': observable ? webviewOutcome(result) : 'not_observed',
  'seconds_open': observable ? open.inSeconds : null,
};
