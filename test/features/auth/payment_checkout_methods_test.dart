import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/models/plan_data.dart' as plans;
import 'package:lantern/features/auth/choose_payment_method.dart';

void main() {
  testWidgets('payment controls have distinct actionable semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final stripe = plans.Android(
      method: 'credit-card',
      providers: plans.Provider(
        name: 'stripe',
        icons: const [],
        supportSubscription: true,
      ),
    );
    final plan = plans.Plan(
      id: '2y-usd-10',
      description: 'Two Year Plan',
      usdPrice: 8700,
      price: const {'usd': 8700},
      expectedMonthlyPrice: const {'usd': 363},
      bestValue: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: Scaffold(
              body: PaymentCheckoutMethods(
                providers: [stripe],
                userPlan: plan,
                isSubmitting: false,
                onSubscribe: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final provider = tester
        .getSemantics(find.bySemanticsIdentifier('payment-provider-stripe'))
        .getSemanticsData();
    final checkout = tester
        .getSemantics(find.bySemanticsIdentifier('payment-checkout-stripe'))
        .getSemanticsData();
    semantics.dispose();

    expect(provider.label, 'Stripe payment method');
    expect(checkout.label, 'Continue with Stripe');
    expect(checkout.hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('automatically starts the selected checkout once', (
    tester,
  ) async {
    final stripe = plans.Android(
      method: 'credit-card',
      providers: plans.Provider(
        name: 'stripe',
        icons: const [],
        supportSubscription: true,
      ),
    );
    final plan = plans.Plan(
      id: '2y-usd-10',
      description: 'Two Year Plan',
      usdPrice: 8700,
      price: const {'usd': 8700},
      expectedMonthlyPrice: const {'usd': 363},
      bestValue: true,
    );
    var starts = 0;
    plans.Android? startedProvider;

    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: Scaffold(
              body: PaymentCheckoutMethods(
                providers: [stripe],
                userPlan: plan,
                isSubmitting: false,
                automaticCheckoutProvider: 'stripe',
                onSubscribe: (provider) {
                  starts++;
                  startedProvider = provider;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(starts, 1);
    expect(startedProvider, same(stripe));
  });
}
