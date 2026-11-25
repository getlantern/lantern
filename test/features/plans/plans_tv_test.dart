import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lantern/features/plans/feature_list.dart';
import 'package:lantern/features/plans/plan_item.dart';
import 'package:lantern/features/plans/plans.dart' as plans_screen;
import 'package:lantern/core/models/referral_attach_response.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';

/// A store with nothing to sell; the screen never asks it for a restore.
class _Store extends Fake implements InAppPurchase {
  @override
  Future<bool> isAvailable() async => true;
}

class _Plans extends PlansNotifier {
  _Plans(this.data);

  final PlansData data;

  @override
  Future<PlansData> build() async => data;
}

class _PlansDown extends PlansNotifier {
  @override
  Future<PlansData> build() async => throw StateError('plans down');
}

/// Plans that load at once; a retry publishes the states the real fetch
/// does (a plain loading state, then data or an error), ending the way the
/// test says.
/// A referral code applied from the test, as the dialog's flow would.
class _Referral extends ReferralNotifier {
  void apply() => state = ReferralAttachV2Response(
    plansData: null,
    code: 'TEST',
    discountPct: 10,
    type: ReferralType.values.first,
  );
}

class _PlansRefetch extends PlansNotifier {
  _PlansRefetch(this.data);

  final PlansData data;

  @override
  Future<PlansData> build() async => data;

  @override
  Future<void> retryFetchPlans() async {
    state = const AsyncLoading();
  }

  void arrive() => state = AsyncData(data);

  void fail() =>
      state = AsyncError(StateError('plans down'), StackTrace.current);
}

/// Plans that arrive when the test says so.
class _PlansLater extends PlansNotifier {
  _PlansLater(this.data);

  final PlansData data;
  final arrived = Completer<void>();

  @override
  Future<PlansData> build() async {
    await arrived.future;
    return data;
  }
}

class _Country extends CountryCodeNotifier {
  @override
  String build() => 'US';
}

Plan _plan(String id, {bool bestValue = false}) => Plan(
  id: id,
  description: id,
  usdPrice: 4800,
  price: const {'usd': 4800},
  expectedMonthlyPrice: const {'usd': 400},
  bestValue: bestValue,
);

void main() {
  setUp(() {
    PlatformUtils.isTv = true;
    PlatformUtils.debugTvShell = true;
    sl.registerSingleton<AppPurchase>(
      AppPurchase(inAppPurchase: _Store(), canUseBilling: () => false),
    );
  });
  tearDown(() {
    PlatformUtils.isTv = false;
    PlatformUtils.debugTvShell = null;
    sl.unregister<AppPurchase>();
  });

  final data = PlansData(
    providers: Providers(android: [], desktop: []),
    plans: [_plan('1m'), _plan('1y'), _plan('2y', bestValue: true)],
  );

  Future<_Plans> pumpPlans(
    WidgetTester tester, {
    bool down = false,
    _PlansLater? later,
    _PlansRefetch? refetch,
    PlansData? plansData,
    bool rtl = false,
    bool oneToOne = false,
    bool pushed = false,
    Size physicalSize = const Size(1920, 1080),
    double devicePixelRatio = 2,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plans = _Plans(plansData ?? data);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (down)
            plansProvider.overrideWith(_PlansDown.new)
          else if (later != null)
            plansProvider.overrideWith(() => later)
          else if (refetch != null)
            plansProvider.overrideWith(() => refetch)
          else
            plansProvider.overrideWith(() => plans),
          countryCodeProvider.overrideWith(_Country.new),
          referralProvider.overrideWith(_Referral.new),
        ],
        child: ScreenUtilInit(
          // A TV lays out 1:1 (designSizeFor); the reference size scales
          // the other tests the way they were written.
          designSize: oneToOne
              ? physicalSize / devicePixelRatio
              : const Size(960, 540),
          child: MaterialApp(
            theme: AppTheme.darkTheme(),
            // The app hosts the loading overlay above its routes.
            builder: (context, child) => LoaderOverlay(
              child: rtl
                  ? Directionality(
                      textDirection: TextDirection.rtl,
                      child: child!,
                    )
                  : child!,
            ),
            home: pushed
                ? const Scaffold(body: SizedBox())
                : const plans_screen.Plans(),
          ),
        ),
      ),
    );
    if (pushed) {
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(builder: (_) => const plans_screen.Plans()),
          );
    }
    // While the plans are still to come the spinner never settles.
    if (later != null) {
      await tester.pump();
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
    return plans;
  }

  String? focusedPlan() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<PlanItem>()
      ?.plan
      .id;

  Key? focusedLink() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<AppTextButton>()
      ?.key;

  bool selected(WidgetTester tester, String id) => tester
      .widget<Radio<bool>>(
        find.descendant(
          of: find.byKey(Key('plans.item.$id')),
          matching: find.byType(Radio<bool>),
        ),
      )
      .groupValue!;

  testWidgets('fills the TV screen with the close, plans, button and links', (
    tester,
  ) async {
    await pumpPlans(tester);
    expect(find.byKey(const Key('plans.close')), findsOneWidget);
    expect(find.byKey(const Key('plans.cta')), findsOneWidget);
    expect(find.byKey(const Key('plans.promo_code')), findsOneWidget);
    expect(find.byKey(const Key('plans.license')), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing, reason: 'no ⋮ on TV');
    // The close glyph sits on the safe margin's corner.
    final close = tester.getCenter(find.byIcon(Icons.close));
    expect(close, const Offset(tvSafeMarginH + 12, tvSafeMarginV + 12));
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
  });

  testWidgets('the best-value plan is preselected and the button has focus', (
    tester,
  ) async {
    final plans = await pumpPlans(tester);
    expect(selected(tester, '2y'), isTrue);
    expect(plans.currentSelectedPlan?.id, '2y');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'plans.cta');
  });

  testWidgets('Up reaches the plans, OK selects one without leaving', (
    tester,
  ) async {
    final plans = await pumpPlans(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focusedPlan(), isNotNull, reason: 'the plan above the button');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    final above = focusedPlan()!;
    expect(above, isNot('2y'));

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected(tester, above), isTrue);
    expect(selected(tester, '2y'), isFalse);
    expect(plans.currentSelectedPlan?.id, above);
    expect(
      find.byType(plans_screen.Plans),
      findsOneWidget,
      reason: 'still on the screen',
    );
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('the Best Value badge sits within its card', (tester) async {
    await pumpPlans(tester);
    final card = tester.getRect(find.byKey(const Key('plans.item.2y')));
    // Every card builds its badge text; only the best-value card shows it.
    final badge = tester.getRect(
      find
          .descendant(
            of: find.byKey(const Key('plans.item.2y')),
            matching: find.text('best_value'.i18n),
          )
          .first,
    );
    expect(badge.left, greaterThanOrEqualTo(card.left));
    expect(badge.right, lessThanOrEqualTo(card.right));
  });

  testWidgets('OK on the promo link opens the code dialog', (tester) async {
    await pumpPlans(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLink(), const Key('plans.promo_code'));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget, reason: 'the code entry');
  });

  testWidgets('an on-screen keyboard does not reflow the screen', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await pumpPlans(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('plans.cta')), findsOneWidget);
  });

  testWidgets('when the plans fail to load, Retry has focus', (tester) async {
    await pumpPlans(tester, down: true);
    expect(find.byKey(const Key('plans.retry')), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<PrimaryButton>()
          ?.buttonKey,
      const Key('plans.retry'),
    );
  });

  testWidgets('the close button is not clipped by the safe margin', (
    tester,
  ) async {
    await pumpPlans(tester);
    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byKey(const Key('plans.close')),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(stack.clipBehavior, Clip.none);
  });

  testWidgets('while a checkout shows the loading overlay the controls and '
      'Back wait, then work again', (tester) async {
    await pumpPlans(tester, pushed: true);
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byKey(const Key('plans.cta')));
    ctx.loaderOverlay.show();
    await tester.pump();
    // Back, Close, the promo link: nothing moves while it is up.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(plans_screen.Plans), findsOneWidget);
    await tester.tap(find.byKey(const Key('plans.close')));
    await tester.pump();
    expect(find.byType(plans_screen.Plans), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focusedLink(), const Key('plans.promo_code'));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.byType(TextField), findsNothing, reason: 'no promo dialog');
    // The checkout ends (every end hides the overlay): Back leaves.
    ctx.loaderOverlay.hide();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(plans_screen.Plans), findsNothing);
  });

  testWidgets('a control that leaves the screen with focus hands it back to '
      'the state\'s target', (tester) async {
    // Applying a referral code removes the promo link.
    final refetch = _PlansRefetch(data);
    await pumpPlans(tester, refetch: refetch);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLink(), const Key('plans.promo_code'));
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('plans.cta'))),
    );
    (container.read(referralProvider.notifier) as _Referral).apply();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plans.promo_code')), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'plans.cta',
      reason: 'nothing had focus, so the button takes it',
    );
  });

  testWidgets('idle, Close leaves Plans for the route below', (tester) async {
    await pumpPlans(tester, pushed: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plans.close')));
    await tester.pumpAndSettle();
    expect(find.byType(plans_screen.Plans), findsNothing);
  });

  testWidgets('a narrower, shorter TV keeps the focused control in view', (
    tester,
  ) async {
    // 1280x600 at 1.5x: 853x400dp, laid out 1:1 as a TV is; four plans so
    // neither column fits.
    final four = PlansData(
      providers: Providers(android: [], desktop: []),
      plans: [
        _plan('1m'),
        _plan('6m'),
        _plan('1y'),
        _plan('2y', bestValue: true),
      ],
    );
    await pumpPlans(
      tester,
      plansData: four,
      physicalSize: const Size(1280, 600),
      devicePixelRatio: 1.5,
      oneToOne: true,
    );
    expect(tester.takeException(), isNull);
    // The right column's own scroll viewport, not the screen.
    final viewport = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const Key('plans.cta')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    bool visible(Finder f) {
      // The visible part: a button's outer rect carries its tap-target
      // padding, and a card's its badge room, neither of which draws the
      // control.
      final ink = find.descendant(of: f, matching: find.byType(InkWell));
      final card = find.descendant(of: f, matching: find.byType(AppFocusable));
      final r = tester.getRect(
        ink.evaluate().isNotEmpty
            ? ink.first
            : card.evaluate().isNotEmpty
            ? card.first
            : f,
      );
      return r.left >= viewport.left - 0.5 &&
          r.top >= viewport.top - 0.5 &&
          r.right <= viewport.right + 0.5 &&
          r.bottom <= viewport.bottom + 0.5;
    }

    expect(
      visible(find.byKey(const Key('plans.cta'))),
      isTrue,
      reason: 'the button is revealed on initial focus',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      visible(find.byKey(const Key('plans.promo_code'))),
      isTrue,
      reason: 'the link is revealed on Down',
    );
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
    }
    expect(
      visible(find.byKey(const Key('plans.item.1m'))),
      isTrue,
      reason: 'the first card is revealed on Up',
    );
  });

  testWidgets('a refetch that keeps the old plans disables the button and '
      'hands focus back when the cards return', (tester) async {
    final refetch = _PlansRefetch(data);
    await pumpPlans(tester, refetch: refetch);
    Key? focusedButton() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<PrimaryButton>()
        ?.buttonKey;
    expect(focusedButton(), const Key('plans.cta'));
    await refetch.retryFetchPlans();
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('plans.cta'))).enabled,
      isFalse,
      reason: 'the cards are reloading',
    );
    expect(focusedLink(), const Key('plans.promo_code'));
    refetch.arrive();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('plans.cta'))).enabled,
      isTrue,
    );
    expect(focusedButton(), const Key('plans.cta'));
  });

  testWidgets('a retry that fails again puts focus back on Retry', (
    tester,
  ) async {
    final refetch = _PlansRefetch(data);
    await pumpPlans(tester, refetch: refetch);
    refetch.fail();
    await tester.pumpAndSettle();
    Key? focusedButton() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<PrimaryButton>()
        ?.buttonKey;
    expect(focusedButton(), const Key('plans.retry'));
    await refetch.retryFetchPlans();
    await tester.pump();
    await tester.pump();
    expect(focusedLink(), const Key('plans.promo_code'), reason: 'reloading');
    refetch.fail();
    await tester.pumpAndSettle();
    expect(focusedButton(), const Key('plans.retry'));
  });

  testWidgets('a viewer who left the placed control and came back keeps it', (
    tester,
  ) async {
    final later = _PlansLater(data);
    await pumpPlans(tester, later: later);
    expect(focusedLink(), const Key('plans.promo_code'), reason: 'placed');
    // Away to the license link and back to the promo link.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(focusedLink(), const Key('plans.license'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 300));
    expect(focusedLink(), const Key('plans.promo_code'));
    later.arrived.complete();
    await tester.pumpAndSettle();
    expect(
      focusedLink(),
      const Key('plans.promo_code'),
      reason: 'the viewer chose it, the button does not take it',
    );
  });

  testWidgets('the button waits for the cards and takes focus when they '
      'arrive', (tester) async {
    final later = _PlansLater(data);
    await pumpPlans(tester, later: later);
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('plans.cta'))).enabled,
      isFalse,
      reason: 'nothing to buy yet',
    );
    expect(
      focusedLink(),
      const Key('plans.promo_code'),
      reason: 'the first link has focus while the cards load',
    );
    later.arrived.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('plans.cta'))).enabled,
      isTrue,
    );
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<PrimaryButton>()
          ?.buttonKey,
      const Key('plans.cta'),
    );
  });

  testWidgets('cards arriving after the viewer moved leave focus alone', (
    tester,
  ) async {
    final later = _PlansLater(data);
    await pumpPlans(tester, later: later);
    // Right, then Down: the test font is wide enough to wrap the links.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(focusedLink(), const Key('plans.license'), reason: 'moved');
    later.arrived.complete();
    await tester.pumpAndSettle();
    expect(focusedLink(), const Key('plans.license'));
  });

  testWidgets('cards arriving under the code dialog leave its focus alone', (
    tester,
  ) async {
    final later = _PlansLater(data);
    await pumpPlans(tester, later: later);
    expect(focusedLink(), const Key('plans.promo_code'));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TextField), findsOneWidget);
    later.arrived.complete();
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>(),
      isNotNull,
      reason: 'the dialog keeps focus',
    );
  });

  testWidgets('a right-to-left locale keeps the benefits left and close '
      'top-left', (tester) async {
    await pumpPlans(tester, rtl: true);
    final close = tester.getTopLeft(find.byKey(const Key('plans.close')));
    final benefits = tester.getTopLeft(find.byType(FeatureList));
    final cta = tester.getTopLeft(find.byKey(const Key('plans.cta')));
    expect(close.dx, lessThan(benefits.dx + 1));
    expect(benefits.dx, lessThan(cta.dx));
  });

  testWidgets('Down from the button reaches the links', (tester) async {
    await pumpPlans(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLink(), const Key('plans.promo_code'));

    // The test font is wide enough to wrap the links onto two lines, so the
    // second link is to the right or below.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLink(), const Key('plans.license'));
  });
}
