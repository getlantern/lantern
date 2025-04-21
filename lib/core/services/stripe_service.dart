import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:lantern/core/common/common.dart';

class StripeService {
  // Add your Stripe service methods here
  // For example, you can create a method to initialize Stripe, handle payments, etc.

  Future<void> initialize() async {
    // Initialize Stripe with your publishable key
    if (PlatformUtils.isAndroid) {
      Stripe.publishableKey = 'pk_test_4MSPZvz9QtXGWEKdODmzV9ql';
      Stripe.urlScheme = 'lantern.io';
      await Stripe.instance.applySettings();
    }
  }

  // Add more methods as needed
  Future<void> startStripeSubscription({
    required StripeOptions options,
    required OnPressed onSuccess,
    required Function(dynamic error) onError,
  }) async {
    // Start Stripe subscription logic
    try {
      // {cus_S95SrFxPUzuB8d sub_1REoO74XJ6zbDKY5lSMoTk94 pi_3REoO74XJ6zbDKY511w5Gpmv_secret_3MnkwSW15QlNePS9tzHAC03O1}
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          // customerEphemeralKeySecret: ephemeralKey,
          paymentIntentClientSecret: options.clientSecret,
          customerId: options.customerId,
          merchantDisplayName: 'Lantern',
          allowsDelayedPaymentMethods: true,
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'IN',
            currencyCode: 'INR',
            testEnv: true,
          ),
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              background: AppColors.gray1,
              componentBackground: AppColors.white,
              primary: AppColors.blue10,
              primaryText: AppColors.gray8,
              secondaryText: AppColors.black,
              icon: AppColors.gray9,
              componentBorder: AppColors.gray3,
              componentDivider: AppColors.gray2,
              componentText: AppColors.gray8,
              error: AppColors.red4,
              placeholderText: AppColors.gray9,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 16,
            ),
          ),
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      onSuccess.call();
    } catch (e) {
      appLogger.error('Error presenting payment sheet: $e');
      onError.call(e);
    }
  }
}

class StripeOptions {
  final String? publishableKey;
  final String clientSecret;
  final String customerId;
  final String subscriptionId;

  StripeOptions({
    this.publishableKey,
    required this.clientSecret,
    required this.customerId,
    required this.subscriptionId,
  });

  factory StripeOptions.fromJson(Map<String, dynamic> json) {
    return StripeOptions(
      publishableKey: json['publishableKey'],
      clientSecret: json['clientSecret'],
      customerId: json['customerId'],
      subscriptionId: json['subscriptionId'],
    );
  }
}
