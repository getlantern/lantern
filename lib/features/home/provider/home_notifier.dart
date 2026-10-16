import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/data_cap_info_provider.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_notifier.g.dart';

@Riverpod(keepAlive: true)
class HomeNotifier extends _$HomeNotifier {
  // Tracked separately from state, which refreshUser() clears to loading
  // before new user data arrives.
  bool _isPro = false;

  @override
  Future<UserResponseModel> build() async {
    /// Check if user data is stored locally
    /// If yes, load it first to avoid delay in UI
    final service = ref.read(lanternServiceProvider);
    await service.waitForRadiance();
    final result = await service.getUserData();
    return result.fold(
      (failure) {
        appLogger.error('Error getting user data: ${failure.error}');
        throw Exception('Failed to get user data');
      },
      (userData) {
        appLogger.debug('Loaded cached user data');
        _applyUserData(userData);
        return userData;
      },
    );
  }

  /// Fetches the latest user data from the server
  Future<void> fetchUserData() async {
    final result = await ref.read(lanternServiceProvider).fetchUserData();
    result.fold(
      (failure) {
        appLogger.error('Error fetching user data: ${failure.error}');
      },
      (userData) {
        appLogger.debug('Fetched user data from server');
        _applyUserData(userData);
      },
    );
  }

  /// Re-reads cached user data from Go without a loading state.
  Future<void> reloadUserData() async {
    // Let a pending build() finish first so its older read cannot overwrite
    // the fresher data.
    try {
      await future;
    } catch (_) {}
    if (!ref.mounted) return;
    final result = await ref.read(lanternServiceProvider).getUserData();
    if (!ref.mounted) return;
    result.fold(
      (failure) {
        appLogger.error('Error reloading user data: ${failure.error}');
      },
      (userData) {
        appLogger.debug('Reloaded cached user data');
        _applyUserData(userData);
      },
    );
  }

  /// Force refresh from Go
  Future<void> refreshUser() async {
    state = const AsyncValue.loading();

    final result = await ref.read(lanternServiceProvider).getUserData();
    result.fold(
      (failure) {
        appLogger.error('Error refreshing user data: ${failure.error}');
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (userData) {
        appLogger.debug('Refreshed cached user data');
        _applyUserData(userData);
      },
    );
  }

  /// Updates the user data in state and local storage.
  /// notifies UI about changes.
  void updateUserData(UserResponseModel userData) {
    _applyUserData(userData);
  }

  void _applyUserData(UserResponseModel userData) {
    final wasPro = _isPro;
    state = AsyncValue.data(userData);

    final isPro = userData.legacyUserData.isPro;
    _isPro = isPro;
    if (wasPro && !isPro) {
      // Data cap info cached while Pro reports the cap as off; refetch it.
      ref.invalidate(dataCapInfoProvider);
    }
    if (!isPro) {
      unawaited(_resetServerLocationIfDataCapped());
    }
    checkIfUserProAndDeviceIsAdded();
  }

  /// Free users without a data cap may keep a manually selected location
  /// (see canSelectServerProvider); everyone else falls back to smart location.
  Future<void> _resetServerLocationIfDataCapped() async {
    try {
      final dataCap = await ref.read(dataCapInfoProvider.future);
      if (!dataCap.enabled) return;
    } catch (e) {
      appLogger.error('Data cap info unavailable, resetting location: $e');
    }
    if (!ref.mounted) return;
    // The user may have upgraded while the data cap info was loading.
    if (_isPro) return;
    await resetServerLocation();
  }

  Future<Either<Failure, Unit>> updateLocale(String locale) {
    final result = ref.read(lanternServiceProvider).updateLocal(locale);
    return result;
  }

  /// Resets the server location to default.
  /// if user logs out or downgrade to free plan
  /// we need to reset the server location set to smart location
  ///
  /// Concurrent callers share one reset, so a switch in flight is never
  /// raced by a second one.
  Future<void> resetServerLocation() => _resetInFlight ??=
      _resetServerLocation().whenComplete(() => _resetInFlight = null);

  Future<void>? _resetInFlight;

  Future<void> _resetServerLocation() async {
    final original = ref.read(serverLocationProvider);
    if (original.serverType.toServerLocationType !=
        ServerLocationType.lanternLocation) {
      return;
    }
    bool stillSelected() {
      if (!ref.mounted) return false;
      final current = ref.read(serverLocationProvider);
      return current.serverType == original.serverType &&
          current.serverName == original.serverName;
    }

    // Abandon the reset if, while it waited, the user picked another
    // location or became free to choose one (upgraded, or cap turned off).
    bool stillApplies() =>
        stillSelected() && !ref.read(canSelectServerProvider);

    // Act on the tunnel's settled state, not a connect or disconnect that is
    // still in progress. If it never settles, keep the manual location rather
    // than guess; the next reset trigger retries.
    if (!await _waitForSettledVpnStatus()) {
      appLogger.warning('VPN status did not settle, skipping location reset');
      return;
    }
    if (!stillApplies()) return;

    // startVPN would turn on a disconnected tunnel, so if the status check
    // fails, skip the reset rather than guess; the next trigger retries.
    // On Android the query itself posts a status event, so remember the
    // app's status first: a change means the query (or the tunnel) moved it.
    final statusBefore = ref.read(vpnProvider);
    final status = await ref.read(lanternServiceProvider).isVPNConnected();
    if (status.isLeft()) {
      appLogger.warning('VPN status unavailable, skipping location reset');
      return;
    }
    final connected = status.getOrElse((_) => false);
    if (!stillApplies()) return;

    // Act only when native and the app agree, the app's status held steady
    // through the check, and no switch the app requested is still running.
    // Otherwise the tunnel is changing (startVPN could start a fresh tunnel,
    // or a manual connect could finish after we save auto) or the app hasn't
    // hydrated yet; the next trigger retries.
    final appStatus = ref.read(vpnProvider);
    final steady =
        appStatus == statusBefore &&
        !ref.read(vpnProvider.notifier).switchInProgress;
    final agreed = connected
        ? appStatus == VPNStatus.connected
        // An error can be reported while a native connect is still running,
        // so only a confirmed disconnect counts.
        : appStatus == VPNStatus.disconnected;
    if (!steady || !agreed) {
      appLogger.debug('VPN state changing, skipping location reset');
      return;
    }

    // A connected tunnel keeps using the manual server until it is switched,
    // so record smart location only once the switch succeeds.
    if (connected) {
      final result = await ref
          .read(vpnProvider.notifier)
          .startVPN(force: true, skipConflictCheck: true);
      if (result.isLeft()) {
        appLogger.error(
          'Failed to switch to smart location, keeping the manual location',
        );
        return;
      }
      // The tunnel is now on auto, so record that even if the user became
      // free to choose meanwhile; only a newer selection takes precedence.
      if (!stillSelected()) return;
      final locations = ref.read(serverLocationProvider.notifier);
      await locations.switchToAuto();
      // server-location events are ignored while the selection is manual, so
      // fetch the resolved auto location that arrived during the switch.
      unawaited(locations.refreshAutoLocationIfNeeded());
      return;
    }
    ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(initialServerLocation());
  }

  /// Waits for any connect or disconnect in progress to finish. Returns
  /// false if it is still in progress after [_vpnSettleTimeout].
  Future<bool> _waitForSettledVpnStatus() async {
    bool settled(VPNStatus status) =>
        status != VPNStatus.connecting && status != VPNStatus.disconnecting;
    if (settled(ref.read(vpnProvider))) return true;

    final done = Completer<bool>();
    final sub = ref.listen<VPNStatus>(vpnProvider, (_, next) {
      if (settled(next) && !done.isCompleted) done.complete(true);
    });
    try {
      return await done.future.timeout(
        _vpnSettleTimeout,
        onTimeout: () => false,
      );
    } finally {
      sub.close();
    }
  }

  // Longer than the native connect timeout (60s on Android), so a slow
  // connect settles before we give up on it.
  static const _vpnSettleTimeout = Duration(seconds: 75);

  /// Fetches the latest user data from the server if not cached locally.
  Future<void> fetchUserDataIfNeeded() async {
    appLogger.info("Checking if user data fetch is needed...");
    appLogger.info("Fetching from Go (source-of-truth)...");
    await refreshUser();
  }

  /// Checks if the user is a Pro user and if the current device is added
  /// means user has logged in from this device before an did not logout.
  /// Updates the app settings accordingly and make user logged in automatically.
  void checkIfUserProAndDeviceIsAdded() {
    final user = state.value;
    if (user == null) {
      appLogger.error("User data is not available to check devices.");
      return;
    }
    _checkIfUserProAndDeviceIsAdded(user);
  }

  void _checkIfUserProAndDeviceIsAdded(UserResponseModel user) {
    if (!user.legacyUserData.isPro) {
      appLogger.info("User is not Pro. Skipping device check.");
      return;
    }
    final appSetting = ref.read(appSettingProvider);
    if (appSetting.userLoggedIn) {
      appLogger.info("User is already logged in. Skipping device check.");
      return;
    }
    final userDeviceId = user.legacyUserData.deviceID;
    final isDeviceAdded = user.legacyUserData.devices.any(
      (device) => device.deviceId == userDeviceId,
    );
    appLogger.info("Current device is linked to the account: $isDeviceAdded");
    if (isDeviceAdded) {
      ref.read(appSettingProvider.notifier).setUserLoggedIn(true);
      appLogger.info(
        "User is Pro and device is added. Logging in automatically.",
      );
    }
  }

  /// Clear any user-specific data upon logout.
  /// Updates server location to fastest.
  /// Fetches available servers again.
  void clearLogoutData() {
    ref.read(referralProvider.notifier).resetReferral();
    ref.read(appSettingProvider.notifier).setUserLoggedIn(false);
    // Defensive: a stale payment-in-flight flag would protect future
    // unrelated signup back-presses from deleting orphaned anonymous accounts.
    ref.read(paymentSessionProvider.notifier).clearRedirect();
  }
}
