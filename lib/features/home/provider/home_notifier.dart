import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_notifier.g.dart';

@Riverpod(keepAlive: true)
class HomeNotifier extends _$HomeNotifier {
  @override
  Future<UserResponse> build() async {
    /// Check if user data is stored locally
    /// If yes, load it first to avoid delay in UI
    final cachedUser = sl<LocalStorageService>().getUser();
    if (cachedUser != null) {
      appLogger.debug('Loaded user data from local storage: $cachedUser');
      state = AsyncValue.data(cachedUser);
    }
    final result = await ref.read(lanternServiceProvider).getUserData();
    return result.fold(
      (failure) {
        appLogger.error(
          'Error getting user data: ${failure.localizedErrorMessage}',
        );
        throw Exception('Failed to get user data');
      },
      (userData) {
        appLogger.debug('Got the userdata: $userData');
        updateUserData(userData);
        return userData;
      },
    );
  }

  /// Fetches the latest user data from the server
  Future<void> fetchUserData() async {
    final result = await ref.read(lanternServiceProvider).fetchUserData();
    result.fold(
      (failure) {
        appLogger.error(
          'Error fetching user data: ${failure.localizedErrorMessage}',
        );
      },
      (userData) {
        appLogger.debug('Fetched user data form server: $userData');
        updateUserData(userData);
      },
    );
  }

  /// Updates the user data in state and local storage.
  /// notifies UI about changes.
  void updateUserData(UserResponse userData) {
    state = AsyncValue.data(userData);
    if (!userData.legacyUserData.isPro()) {
      resetServerLocation();
    }
    String email;
    if (userData.legacyUserData.email.isEmpty) {
      email = userData.id;
    } else {
      email = userData.legacyUserData.email;
    }
    ref.read(appSettingProvider.notifier).setEmail(email);
    sl<LocalStorageService>().saveUser(userData.toEntity());
    checkIfUserProAndDeviceIsAdded();
  }

  Future<Either<Failure, Unit>> updateLocale(String locale) {
    final result = ref.read(lanternServiceProvider).updateLocal(locale);
    return result;
  }

  /// Resets the server location to default.
  /// if user logs out or downgrade to free plan
  /// we need to reset the server location set to smart location
  void resetServerLocation() {
    final serverLocation = ref.read(serverLocationProvider);
    if (serverLocation.serverType.toServerLocationType ==
        ServerLocationType.lanternLocation) {
      appLogger.debug(
        "User is not Pro. Resetting server location to default (Fastest Country).",
      );
      ref
          .read(serverLocationProvider.notifier)
          .updateServerLocation(initialServerLocation());
    }
  }

  /// Fetches the latest user data from the server if not cached locally.
  Future<void> fetchUserDataIfNeeded() async {
    appLogger.info("Checking if user data fetch is needed...");
    final cachedUser = sl<LocalStorageService>().getUser();
    if (cachedUser == null) {
      appLogger.info("No cached user data found. Fetching from server...");
      fetchUserData();
    }
  }

  /// Checks if the user is a Pro user and if the current device is added
  /// means user has logged in from this device before an did not logout.
  /// Updates the app settings accordingly and make user logged in automatically.
  void checkIfUserProAndDeviceIsAdded() {
    final user = sl<LocalStorageService>().getUser();
    if (user == null) {
      appLogger.error("User data is not available to check devices.");
      return;
    }
    if (!user.legacyUserData.isPro()) {
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
      (device) => device.id == userDeviceId,
    );
    appLogger.info(
      "current device added for user ${user.legacyUserData.email}: $isDeviceAdded",
    );
    if (isDeviceAdded) {
      ref.read(appSettingProvider.notifier)
        ..setUserLoggedIn(true)
        ..setEmail(user.legacyUserData.email);
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
  }
}
