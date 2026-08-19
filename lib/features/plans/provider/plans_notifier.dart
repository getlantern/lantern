import 'dart:async';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/stripe_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plans_notifier.g.dart';

@Riverpod()
class PlansNotifier extends _$PlansNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();

  Plan? userSelectedPlan;

  // build() reruns on the same notifier instance when the provider is
  // invalidated, but listenSelf subscriptions survive rebuilds — without this
  // guard every rebuild would stack another listener.
  bool _stripeKeyListenerAttached = false;

  /// Plans are only published after this completes, so the first paint
  /// already shows store prices (Plan.displayPrice) instead of flickering.
  Future<void> _storeProductsReady = Future.value();

  @override
  Future<PlansData> build() async {
    // Every plans arrival (cache, fetch, referral update) funnels through
    // state, so this one listener keeps the Stripe key in sync. StripeService
    // is only registered on Android, hence the guard.
    if (!_stripeKeyListenerAttached && sl.isRegistered<StripeService>()) {
      _stripeKeyListenerAttached = true;
      listenSelf(
        (_, next) => next.whenData(
          (plans) =>
              sl<StripeService>().updatePublishableKey(plans.stripePubKey),
        ),
      );
    }

    state = const AsyncLoading();
    // Fetched in parallel with the plans; awaited before publishing.
    _storeProductsReady = _loadStoreProducts();
    final cached = _storage.getPlans();
    if (cached != null) {
      appLogger.info('Found cached plans, refreshing in background');
      unawaited(_refreshInBackground());
      await _storeProductsReady;
      state = AsyncData(cached);
      return cached;
    }

    appLogger.info('No cached plans, fetching from server');
    return fetchPlans();
  }

  Future<PlansData> fetchPlans({bool fromBackground = false}) async {
    return _fetchPlansWithRetry(fromBackground: fromBackground, attempt: 0);
  }

  Future<PlansData> _fetchPlansWithRetry({
    required bool fromBackground,
    required int attempt,
  }) async {
    appLogger.info(
      '[PlansNotifier] _fetchPlansWithRetry(fromBackground: $fromBackground, attempt: $attempt)',
    );
    if (!fromBackground && attempt == 0) {
      state = const AsyncLoading();
    }
    final result = await ref.read(lanternServiceProvider).plans();
    return result.fold(
      (error) {
        appLogger.error(
          '[PlansNotifier] Plans fetch error: $error (fromBackground: $fromBackground, attempt: $attempt)',
        );
        if (fromBackground) {
          return state.value ?? (throw Exception('Plans fetch failed'));
        }
        // Retry up to 2 times with increasing delay — the first attempt
        // often fails at startup before radiance is fully ready.
        if (attempt < 2) {
          appLogger.info(
            '[PlansNotifier] Retrying plans fetch (${attempt + 1}/2) after ${2 * (attempt + 1)}s delay...',
          );
          return Future.delayed(
            Duration(seconds: 2 * (attempt + 1)),
            () => _fetchPlansWithRetry(
              fromBackground: false,
              attempt: attempt + 1,
            ),
          );
        }
        appLogger.error(
          '[PlansNotifier] All retry attempts exhausted, setting error state',
        );
        state = AsyncError(error, StackTrace.current);
        throw Exception('Plans fetch failed');
      },
      (remote) async {
        appLogger.info(
          '[PlansNotifier] Plans fetched successfully: ${remote.plans.length} plans',
        );
        unawaited(_storage.savePlans(remote));
        // Never throws — see _loadStoreProducts.
        await _storeProductsReady;
        // Publish the result so standalone callers (the "Try again" button and
        // removing an affiliate code) leave the loading state. When invoked
        // from build() the framework also assigns the returned value — this
        // extra set is harmless and redundant there.
        state = AsyncData(remote);
        return remote;
      },
    );
  }

  /// Loads store products on store builds; never throws — on failure or
  /// timeout (the billing client has none of its own) cards show API prices.
  Future<void> _loadStoreProducts() async {
    if (!isStoreVersion()) return;
    try {
      await sl<AppPurchase>().fetchSubscriptions().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      appLogger.warning(
        '[PlansNotifier] Store products unavailable, showing API prices: $e',
      );
    }
  }

  Future<void> _refreshInBackground() async {
    appLogger.info('[PlansNotifier] _refreshInBackground started');
    final remotePlans = await fetchPlans(fromBackground: true);
    appLogger.info(
      '[PlansNotifier] Background refresh complete, updating state',
    );
    state = AsyncData(remotePlans);
  }

  /// Replaces the current plans with [plans] — e.g. the discounted plans
  /// returned after applying a referral code. Kept in-memory only: the
  /// discount is session-specific and must not overwrite the cached base
  /// plans used by non-referral sessions.
  void updatePlans(PlansData plans) {
    appLogger.info('[PlansNotifier] updatePlans: ${plans.plans.length} plans');
    state = AsyncData(plans);
  }

  void setSelectedPlan(Plan plan) {
    appLogger.info('[PlansNotifier] setSelectedPlan: ${plan.id}');
    userSelectedPlan = plan;
  }

  Plan getSelectedPlan() {
    appLogger.info('[PlansNotifier] getSelectedPlan: ${userSelectedPlan?.id}');
    return userSelectedPlan!;
  }
}
