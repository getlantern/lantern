import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/user.dart';

enum StripeIntentMode { payment, setup }

/// Mirrors the backend's active one-time-purchase branch closely enough to
/// choose the deferred PaymentSheet intent type before the backend creates the
/// subscription. The backend returns a SetupIntent only for this case.
StripeIntentMode stripeIntentModeForRenewal(
  UserDataModel? userData, {
  int? currentTimeSeconds,
}) {
  if (userData == null) return StripeIntentMode.payment;

  final now =
      currentTimeSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final purchases = userData.purchases.trim();
  final hasPurchaseHistory = purchases.isNotEmpty && purchases != '[]';
  final hasActiveOneTimePurchase =
      userData.isPro &&
      userData.expiration > now &&
      !userData.subscriptionData.autoRenew &&
      userData.subscriptionData.subscriptionID.isEmpty &&
      hasPurchaseHistory;

  return hasActiveOneTimePurchase
      ? StripeIntentMode.setup
      : StripeIntentMode.payment;
}

class StripeService {
  /// Adopts the publishable key advertised by the plans response so the SDK
  /// always confirms intents against the same Stripe account/environment the
  /// backend creates them in (prod → live key, staging → test key). The SDK
  /// no-ops on an unchanged key. PaymentSheet applies and awaits changed
  /// settings before it initializes.
  void updatePublishableKey(String? pubKey) {
    if (pubKey == null || pubKey.isEmpty) return;
    Stripe.publishableKey = pubKey;
  }

  /// Presents the payment sheet using Stripe's deferred-intent flow: no
  /// subscription (or any Stripe object) exists until the user actually taps
  /// Pay. Only then does the sheet invoke [onCreateSubscription]; the backend
  /// creates the subscription and returns its intent client secret, which the
  /// SDK confirms client-side. Dismissing the sheet without paying therefore
  /// leaves nothing behind — no abandoned `incomplete` subscriptions on
  /// Stripe or in our DB.
  ///
  /// [amount] is the plan's price in USD cents (the sheet's display total).
  ///
  /// This is only used by android.
  Future<void> startStripeSDK({
    required BuildContext context,
    required int amount,
    required String email,
    required StripeIntentMode intentMode,
    required Future<StripeOptions> Function() onCreateSubscription,
    required OnPressed onSuccess,
    required Function(dynamic error) onError,
  }) async {
    try {
      appLogger.info(
        'Stripe: starting deferred-intent flow (amount: $amount cents)',
      );
      // Extract all context-dependent values before any async gap
      final brightness = Theme.of(context).brightness;
      final style = brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
      final sheetColors = PaymentSheetAppearanceColors(
        background: context.bgSurface,
        componentBackground: context.bgElevated,
        primary: context.actionPrimaryBg,
        primaryText: context.textPrimary,
        secondaryText: context.textSecondary,
        icon: context.textTertiary,
        componentBorder: context.borderInput,
        componentDivider: context.borderDefault,
        componentText: context.textPrimary,
        error: AppColors.red4,
        placeholderText: context.textDisabled,
      );

      // PaymentSheet can invoke its confirmation callback again when the user
      // retries. Reuse the subscription that was already created so a retry
      // cannot create another incomplete subscription. A failed request is
      // cleared so a transient backend failure remains retryable.
      Future<StripeOptions>? subscriptionFuture;
      Future<StripeOptions> createSubscriptionOnce() async {
        final existing = subscriptionFuture;
        if (existing != null) return existing;

        final pending = onCreateSubscription();
        subscriptionFuture = pending;
        try {
          return await pending;
        } catch (_) {
          if (identical(subscriptionFuture, pending)) {
            subscriptionFuture = null;
          }
          rethrow;
        }
      }

      // initPaymentSheet applies any pending settings (including the
      // publishable key) to the native SDK itself. If plans never provided
      // a key, this throws StripeConfigException into the catch below.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          intentConfiguration: IntentConfiguration(
            mode: switch (intentMode) {
              StripeIntentMode.payment => IntentMode.paymentMode(
                currencyCode: 'USD',
                amount: amount,
                // The subscription charges this payment method on renewal, so
                // it must be saved for off-session reuse.
                setupFutureUsage: IntentFutureUsage.OffSession,
              ),
              StripeIntentMode.setup => const IntentMode.setupMode(
                currencyCode: 'USD',
                setupFutureUsage: IntentFutureUsage.OffSession,
              ),
            },
            // The SDK confirms the intent itself with the payment method it
            // collected, so neither callback argument is needed here.
            confirmHandler: (_, _) async {
              await _createSubscriptionAndConfirm(
                createSubscriptionOnce,
                intentMode,
              );
            },
          ),
          merchantDisplayName: 'Lantern Pro',
          allowsDelayedPaymentMethods: true,
          // Prefill the checkout email so the user doesn't retype it; Stripe
          // also uses it for receipts and Link lookup.
          billingDetails: email.isEmpty ? null : BillingDetails(email: email),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'USD',
            testEnv: kDebugMode,
          ),
          appearance: PaymentSheetAppearance(
            colors: sheetColors,
            shapes: PaymentSheetShape(borderRadius: 16),
          ),
          style: style,
        ),
      );

      appLogger.info('Stripe: payment sheet initialized, presenting');
      await Stripe.instance.presentPaymentSheet();
      appLogger.info('Stripe: payment completed successfully');
      onSuccess.call();
    } catch (e) {
      if (e is StripeException && e.error.code == FailureCode.Canceled) {
        appLogger.info('Stripe: payment sheet dismissed by user');
      } else {
        appLogger.error('Error presenting payment sheet: ${e.toString()}', e);
      }
      onError.call(e);
    }
  }

  /// Runs inside the sheet's confirm step: creates the subscription on the
  /// backend and hands its intent client secret back to the SDK via
  /// intentCreationCallback (the reply channel matching confirmHandler).
  /// Errors are reported the same way so the sheet surfaces them inline and
  /// lets the user retry, instead of crashing the flow.
  Future<void> _createSubscriptionAndConfirm(
    Future<StripeOptions> Function() onCreateSubscription,
    StripeIntentMode intentMode,
  ) async {
    try {
      appLogger.info('Stripe: user tapped Pay, creating subscription');
      final options = await onCreateSubscription();
      appLogger.info(
        'Stripe: subscription created '
        '(subscriptionId: ${options.subscriptionId}, '
        'secret type: ${options.clientSecret.isNotEmpty ? 'payment' : 'setup'})',
      );
      // The client must return the same kind of intent used to initialize the
      // deferred sheet. Active one-time purchases start with a free trial and
      // therefore return a SetupIntent; ordinary purchases return a
      // PaymentIntent.
      final secret = switch (intentMode) {
        StripeIntentMode.payment => options.clientSecret,
        StripeIntentMode.setup => options.setupIntentClientSecret,
      };

      if (secret.isEmpty) {
        throw Exception(
          'Please try again after some time. If the issue persists, contact support.',
        );
      }
      await Stripe.instance.intentCreationCallback(
        IntentCreationCallbackParams(clientSecret: secret),
      );
      appLogger.info('Stripe: client secret handed to SDK for confirmation');
    } catch (e) {
      appLogger.error('Error creating subscription during confirm', e);
      // Backend failures arrive as Exception(<already-localized message>);
      // strip the "Exception: " prefix. Stripe failures go through the same
      // developer-text filter as the snackbar path.
      final message = e is StripeException
          ? e.userFacingMessage
          : e.toString().replaceFirst('Exception: ', '');
      await Stripe.instance.intentCreationCallback(
        IntentCreationCallbackParams(
          error: StripeException(
            error: LocalizedErrorMessage(
              code: FailureCode.Failed,
              localizedMessage: message,
              message: message,
            ),
          ),
        ),
      );
    }
  }
}

extension StripeErrorMessage on StripeException {
  /// Stripe types whose localized messages are intended for customers. An
  /// allowlist keeps new API/integration error types from accidentally
  /// exposing developer details or publishable keys in the UI.
  static const _userFacingErrorTypes = {'card_error', 'validation_error'};

  /// A message safe to show the user for this Stripe failure.
  String get userFacingMessage {
    if (_userFacingErrorTypes.contains(error.type) ||
        error.declineCode != null) {
      return error.localizedMessage ??
          error.message ??
          'an_error_occurred'.i18n;
    }
    return 'an_error_occurred'.i18n;
  }
}

class StripeOptions {
  final String clientSecret;
  final String setupIntentClientSecret;
  final String subscriptionId;

  StripeOptions({
    required this.clientSecret,
    required this.setupIntentClientSecret,
    required this.subscriptionId,
  });

  factory StripeOptions.fromJson(Map<String, dynamic> json) {
    return StripeOptions(
      clientSecret: json['clientSecret'] ?? '',
      setupIntentClientSecret: json['pending_secret'] ?? '',
      subscriptionId: json['subscriptionId'] ?? '',
    );
  }
}
