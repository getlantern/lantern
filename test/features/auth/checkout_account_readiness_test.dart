import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme, AuthFlow;
import 'package:lantern/core/models/user.dart';
import 'package:lantern/features/auth/choose_payment_method.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

class _PendingHomeNotifier extends HomeNotifier {
  _PendingHomeNotifier(this.account);

  final Future<UserResponseModel> account;

  @override
  Future<UserResponseModel> build() => account;
}

void main() {
  // Create each completer inside testWidgets so pump() can flush its callbacks.
  late Completer<UserResponseModel> account;
  late ProviderContainer container;
  late ValueNotifier<bool> inFlight;
  late BuildContext screenContext;
  late WidgetRef screenRef;

  const checkout = ChoosePaymentMethod(
    email: 'person@example.com',
    authFlow: AuthFlow.renewSubscription,
  );

  setUp(() {
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        homeProvider.overrideWith(() => _PendingHomeNotifier(account.future)),
      ],
    );
    inFlight = ValueNotifier(false);
  });

  tearDown(() {
    container.dispose();
    inFlight.dispose();
  });

  Widget harness() => UncontrolledProviderScope(
    container: container,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        theme: AppTheme.appTheme(),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              screenContext = context;
              screenRef = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );

  testWidgets('waits for the account and stops if checkout closes', (
    tester,
  ) async {
    account = Completer<UserResponseModel>();
    await tester.pumpWidget(harness());
    final result = checkout.paymentRedirectFlow(
      'shepherd',
      screenRef,
      screenContext,
      inFlight,
    );
    await tester.pump();
    expect(inFlight.value, isTrue);

    // No payment service or plans are installed: checkout must not reach
    // either while its account baseline is still unavailable.
    await tester.pumpWidget(const SizedBox());
    account.complete(
      const UserResponseModel(
        legacyID: 1,
        legacyToken: 'test-token',
        emailConfirmed: true,
        success: true,
        legacyUserData: UserDataModel(userLevel: 'pro', expiration: 200),
      ),
    );
    await tester.pump();
    await result;
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not open checkout when the account cannot be loaded', (
    tester,
  ) async {
    account = Completer<UserResponseModel>();
    await tester.pumpWidget(harness());
    final result = checkout.paymentRedirectFlow(
      'shepherd',
      screenRef,
      screenContext,
      inFlight,
    );
    account.completeError(StateError('account unavailable'));
    await tester.pump();
    await result;

    expect(inFlight.value, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
