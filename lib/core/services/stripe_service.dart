import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/common/common.dart';

class StripeService {
  Future<void> initialize() async {
    try {
      final String publishableKey;
      if (kDebugMode) {
        publishableKey = AppSecrets.stripeTestPublishableKey;
        appLogger.info('Found debug mode using test stripe key');
      } else {
        publishableKey = AppSecrets.stripePublishableKey;
        if (publishableKey.isEmpty) {
          throw StateError('Missing STRIPE_PUBLISHABLE_KEY');
        }
      }
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
    } catch (e, st) {
      appLogger.error('Error initializing Stripe', e, st);
    }
  }

  // This method is used to start a Stripe subscription
  // It takes the StripeOptions object and a callback function for success and error handling
  // this is only used by android
  Future<void> startStripeSDK({
    required BuildContext context,
    required StripeOptions options,
    required OnPressed onSuccess,
    required Function(dynamic error) onError,
  }) async {
    try {
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
      if (options.clientSecret.isEmpty &&
          options.setupIntentClientSecret.isEmpty) {
        throw Exception(
          'Please try again after some time. If the issue persists, contact support.',
        );
      }
      if (options.publishableKey != null &&
          options.publishableKey!.isNotEmpty) {
        Stripe.publishableKey = options.publishableKey!;
        appLogger.info('Using provided publishable key for API calls');
      }
      await Stripe.instance.applySettings();

      /// Just a safety check to ensure the publishable key is set
      /// before proceeding
      if ((options.publishableKey != null && options.publishableKey!.isEmpty) ||
          Stripe.publishableKey.isEmpty) {
        throw StateError('Missing STRIPE_PUBLISHABLE_KEY');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: options.clientSecret.isEmpty
              ? null
              : options.clientSecret,
          setupIntentClientSecret: options.setupIntentClientSecret.isEmpty
              ? null
              : options.setupIntentClientSecret,
          customerId: options.customerId,
          merchantDisplayName: 'Lantern Pro',
          allowsDelayedPaymentMethods: true,
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

      await Stripe.instance.presentPaymentSheet();
      onSuccess.call();
    } catch (e) {
      appLogger.error('Error presenting payment sheet: ${e.toString()}', e);
      onError.call(e);
    }
  }
}

class StripeOptions {
  final String? publishableKey;
  final String clientSecret;
  final String setupIntentClientSecret;
  final String customerId;
  final String subscriptionId;

  StripeOptions({
    this.publishableKey,
    required this.clientSecret,
    required this.setupIntentClientSecret,
    required this.customerId,
    required this.subscriptionId,
  });

  factory StripeOptions.fromJson(Map<String, dynamic> json) {
    return StripeOptions(
      publishableKey: json['publishableKey'] ?? '',
      clientSecret: json['clientSecret'] ?? '',
      setupIntentClientSecret: json['pending_secret'] ?? '',
      customerId: json['customerId'] ?? '',
      subscriptionId: json['subscriptionId'] ?? '',
    );
  }
}
