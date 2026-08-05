import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/stripe_service.dart';

void main() {
  late _FakeStripePlatform platform;

  setUpAll(() {
    platform = _FakeStripePlatform();
    StripePlatform.instance = platform;
  });

  setUp(() {
    platform.reset();
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.appTheme(),
        home: Builder(
          builder: (context) {
            result = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('publishable key is applied before PaymentSheet initializes', (
    tester,
  ) async {
    final service = StripeService();
    final context = await pumpContext(tester);

    service.updatePublishableKey('pk_test_deferred_settings');
    expect(platform.events, isEmpty);

    await tester.runAsync(
      () => service.startStripeSDK(
        context: context,
        amount: 1200,
        email: '',
        intentMode: StripeIntentMode.payment,
        onCreateSubscription: () => throw StateError('should not be called'),
        onSuccess: () {},
        onError: (dynamic error) =>
            throw TestFailure('Unexpected Stripe error: $error'),
      ),
    );

    expect(platform.events, [
      'initialise:start',
      'initialise:end',
      'payment-sheet:init',
      'payment-sheet:present',
    ]);
  });

  testWidgets('payment retries reuse the created subscription', (tester) async {
    final service = StripeService();
    final context = await pumpContext(tester);
    var creationCount = 0;
    platform.confirmationsToRun = 2;

    await tester.runAsync(
      () => service.startStripeSDK(
        context: context,
        amount: 1200,
        email: 'user@example.com',
        intentMode: StripeIntentMode.payment,
        onCreateSubscription: () async {
          creationCount++;
          return StripeOptions(
            clientSecret: 'pi_secret',
            setupIntentClientSecret: '',
            subscriptionId: 'sub_123',
          );
        },
        onSuccess: () {},
        onError: (dynamic error) =>
            throw TestFailure('Unexpected Stripe error: $error'),
      ),
    );

    expect(creationCount, 1);
    expect(platform.intentCallbacks, hasLength(2));
    expect(
      platform.intentCallbacks.map((callback) => callback.clientSecret),
      everyElement('pi_secret'),
    );
    expect(
      platform.paymentSheetParameters!.intentConfiguration!.mode.toJson(),
      containsPair('runtimeType', 'paymentMode'),
    );
  });

  testWidgets('a failed subscription request can be retried', (tester) async {
    final service = StripeService();
    final context = await pumpContext(tester);
    var creationCount = 0;
    platform.confirmationsToRun = 2;

    await tester.runAsync(
      () => service.startStripeSDK(
        context: context,
        amount: 1200,
        email: 'user@example.com',
        intentMode: StripeIntentMode.payment,
        onCreateSubscription: () async {
          creationCount++;
          if (creationCount == 1) throw Exception('Temporary failure');
          return StripeOptions(
            clientSecret: 'pi_retry_secret',
            setupIntentClientSecret: '',
            subscriptionId: 'sub_retry',
          );
        },
        onSuccess: () {},
        onError: (dynamic error) =>
            throw TestFailure('Unexpected Stripe error: $error'),
      ),
    );

    expect(creationCount, 2);
    expect(platform.intentCallbacks.first.error, isNotNull);
    expect(platform.intentCallbacks.last.clientSecret, 'pi_retry_secret');
  });

  testWidgets('setup mode confirms the backend SetupIntent', (tester) async {
    final service = StripeService();
    final context = await pumpContext(tester);
    platform.confirmationsToRun = 1;

    await tester.runAsync(
      () => service.startStripeSDK(
        context: context,
        amount: 1200,
        email: 'user@example.com',
        intentMode: StripeIntentMode.setup,
        onCreateSubscription: () async => StripeOptions(
          clientSecret: '',
          setupIntentClientSecret: 'seti_secret',
          subscriptionId: 'sub_trial',
        ),
        onSuccess: () {},
        onError: (dynamic error) =>
            throw TestFailure('Unexpected Stripe error: $error'),
      ),
    );

    expect(platform.intentCallbacks.single.clientSecret, 'seti_secret');
    expect(
      platform.paymentSheetParameters!.intentConfiguration!.mode.toJson(),
      containsPair('runtimeType', 'setupMode'),
    );
  });

  group('StripeErrorMessage', () {
    StripeException stripeError({
      required String type,
      String? localizedMessage,
      String? declineCode,
    }) => StripeException(
      error: LocalizedErrorMessage(
        code: FailureCode.Failed,
        type: type,
        localizedMessage: localizedMessage,
        declineCode: declineCode,
      ),
    );

    test('shows card and validation errors', () {
      expect(
        stripeError(
          type: 'card_error',
          localizedMessage: 'Your card was declined.',
        ).userFacingMessage,
        'Your card was declined.',
      );
      expect(
        stripeError(
          type: 'validation_error',
          localizedMessage: 'Check the card number.',
        ).userFacingMessage,
        'Check the card number.',
      );
    });

    test('shows decline messages even when Stripe omits the type', () {
      expect(
        stripeError(
          type: '',
          localizedMessage: 'Insufficient funds.',
          declineCode: 'insufficient_funds',
        ).userFacingMessage,
        'Insufficient funds.',
      );
    });

    test('hides known and unknown integration errors', () {
      final apiMessage = stripeError(
        type: 'api_error',
        localizedMessage: 'Expired API Key: pk_live_sensitive',
      ).userFacingMessage;
      final unknownMessage = stripeError(
        type: 'future_internal_error',
        localizedMessage: 'Internal Stripe detail',
      ).userFacingMessage;

      expect(apiMessage, isNot(contains('pk_live_sensitive')));
      expect(unknownMessage, apiMessage);
    });
  });

  test(
    'StripeOptions keeps PaymentIntent and SetupIntent secrets separate',
    () {
      final options = StripeOptions.fromJson({
        'clientSecret': 'pi_secret',
        'pending_secret': 'seti_secret',
        'subscriptionId': 'sub_123',
      });

      expect(options.clientSecret, 'pi_secret');
      expect(options.setupIntentClientSecret, 'seti_secret');
      expect(options.subscriptionId, 'sub_123');
    },
  );

  group('stripeIntentModeForRenewal', () {
    test('uses setup mode for an unexpired one-time purchaser', () {
      const user = UserDataModel(
        userLevel: 'pro',
        expiration: 2000,
        purchases: '[{plan: yearly}]',
      );

      expect(
        stripeIntentModeForRenewal(user, currentTimeSeconds: 1000),
        StripeIntentMode.setup,
      );
    });

    test('uses payment mode without an active one-time purchase', () {
      const expiredPurchase = UserDataModel(
        userLevel: 'pro',
        expiration: 500,
        purchases: '[{plan: yearly}]',
      );
      const activeSubscription = UserDataModel(
        userLevel: 'pro',
        expiration: 2000,
        purchases: '[{plan: yearly}]',
        subscriptionData: SubscriptionDataModel(
          subscriptionID: 'sub_existing',
          autoRenew: true,
        ),
      );
      const noPurchase = UserDataModel(
        userLevel: 'pro',
        expiration: 2000,
        purchases: '[]',
      );

      expect(
        stripeIntentModeForRenewal(expiredPurchase, currentTimeSeconds: 1000),
        StripeIntentMode.payment,
      );
      expect(
        stripeIntentModeForRenewal(
          activeSubscription,
          currentTimeSeconds: 1000,
        ),
        StripeIntentMode.payment,
      );
      expect(
        stripeIntentModeForRenewal(noPurchase, currentTimeSeconds: 1000),
        StripeIntentMode.payment,
      );
    });
  });
}

class _FakeStripePlatform extends StripePlatform {
  final events = <String>[];
  final intentCallbacks = <IntentCreationCallbackParams>[];
  SetupPaymentSheetParameters? paymentSheetParameters;
  ConfirmHandler? _confirmHandler;
  Completer<void>? _intentCallbackCompleter;
  int confirmationsToRun = 0;

  void reset() {
    events.clear();
    intentCallbacks.clear();
    paymentSheetParameters = null;
    _confirmHandler = null;
    _intentCallbackCompleter = null;
    confirmationsToRun = 0;
  }

  @override
  Future<void> initialise({
    required String publishableKey,
    String? stripeAccountId,
    ThreeDSecureConfigurationParams? threeDSecureParams,
    String? merchantIdentifier,
    String? urlScheme,
    bool? setReturnUrlSchemeOnAndroid,
  }) async {
    events.add('initialise:start');
    events.add('initialise:end');
  }

  @override
  Future<PaymentSheetPaymentOption?> initPaymentSheet(
    SetupPaymentSheetParameters params,
  ) async {
    events.add('payment-sheet:init');
    paymentSheetParameters = params;
    _confirmHandler = params.intentConfiguration?.confirmHandler;
    return null;
  }

  @override
  Future<PaymentSheetPaymentOption?> presentPaymentSheet({
    PaymentSheetPresentOptions? options,
  }) async {
    events.add('payment-sheet:present');
    for (var i = 0; i < confirmationsToRun; i++) {
      _intentCallbackCompleter = Completer<void>();
      _confirmHandler!.call(_paymentMethod, false);
      await _intentCallbackCompleter!.future;
    }
    return null;
  }

  @override
  Future<void> intentCreationCallback(
    IntentCreationCallbackParams params,
  ) async {
    intentCallbacks.add(params);
    _intentCallbackCompleter?.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _paymentMethod = PaymentMethod(
  id: 'pm_test',
  livemode: false,
  paymentMethodType: 'card',
  billingDetails: BillingDetails(),
  card: Card(),
  sepaDebit: SepaDebit(),
  bacsDebit: BacsDebit(),
  auBecsDebit: AuBecsDebit(),
  ideal: Ideal(),
  fpx: Fpx(),
  upi: Upi(),
  usBankAccount: UsBankAccount(),
);
