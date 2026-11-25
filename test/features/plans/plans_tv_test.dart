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
import 'package:lantern/features/plans/provider/plans_notifier.dart';

/// A store whose restore never finishes, to hold an operation in flight.
class _Store extends Fake implements InAppPurchase {
  int restores = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> restorePurchases({String? applicationUserName}) {
    restores++;
    return Completer<void>().future;
  }
}

/// The store the billing-enabled tests register.
_Store? _store;

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

/// Plans that load at once and can be sent back through loading, keeping
/// the previous value as Riverpod does on a refetch.
class _PlansRefetch extends PlansNotifier {
  _PlansRefetch(this.data);

  final PlansData data;

  @override
  Future<PlansData> build() async => data;

  @override
  Future<void> retryFetchPlans() async {
    // A reload, as fetchPlans publishes: the previous value is kept on the
    // loading state (Riverpod) while the cards show their spinner.
    state = const AsyncLoading<PlansData>().copyWithPrevious(
      state,
      isRefresh: false,
    );
  }

  void arrive() => state = AsyncData(data);

  void fail() => state = AsyncError<PlansData>(
    StateError('plans down'),
    StackTrace.empty,
  ).copyWithPrevious(state);
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
    bool billing = false,
    bool down = false,
    _PlansLater? later,
    _PlansRefetch? refetch,
    PlansData? plansData,
    bool rtl = false,
    bool oneToOne = false,
    Size physicalSize = const Size(1920, 1080),
    double devicePixelRatio = 2,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (billing) {
      sl.unregister<AppPurchase>();
      _store = _Store();
      sl.registerSingleton<AppPurchase>(
        AppPurchase(inAppPurchase: _store, canUseBilling: () => true),
      );
    }
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
            home: const plans_screen.Plans(),
          ),
        ),
      ),
    );
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
    expect(
      find.byKey(const Key('plans.restore')),
      findsNothing,
      reason: 'no store billing here',
    );
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

  testWidgets('Restore Purchase shows first among the links when store '
      'billing is available', (tester) async {
    await pumpPlans(tester, billing: true);
    expect(find.byKey(const Key('plans.restore')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLink(), const Key('plans.restore'));
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

  testWidgets('a store operation in flight blocks a second one from the '
      'remote until it ends', (tester) async {
    await pumpPlans(tester, billing: true);
    final store = _store!;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLink(), const Key('plans.restore'));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();
    expect(store.restores, 1, reason: 'the restore is in flight');
    // A second Restore, and checkout from the button, while it runs.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(store.restores, 1, reason: 'no second store operation');
    expect(tester.takeException(), isNull, reason: 'checkout did not start');
    // The operation ends (every end hides the overlay): the guard lifts.
    tester.element(find.byKey(const Key('plans.cta'))).loaderOverlay.hide();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();
    expect(store.restores, 2);
  });

  testWidgets('a narrower TV keeps the focused control in view', (
    tester,
  ) async {
    // 1280x720 at 1.5x: 853x480dp, laid out 1:1 as a TV is; four plans so
    // the right column does not fit.
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
      physicalSize: const Size(1280, 720),
      devicePixelRatio: 1.5,
      oneToOne: true,
    );
    expect(tester.takeException(), isNull);
    const viewport = Rect.fromLTWH(0, 0, 853.3, 480);
    bool visible(Finder f) =>
        viewport.contains(tester.getRect(f).topLeft) &&
        viewport.contains(tester.getRect(f).bottomRight);
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
