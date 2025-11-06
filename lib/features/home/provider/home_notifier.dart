import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pbserver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_notifier.g.dart';

@Riverpod(keepAlive: true)
class HomeNotifier extends _$HomeNotifier {
  @override
  Future<UserResponse> build() async {
    final result = await ref.read(lanternServiceProvider).getUserData();
    return result.fold(
      (failure) {
        appLogger
            .error('Error getting user data: ${failure.localizedErrorMessage}');
        throw Exception('Failed to get user data');
      },
      (userData) {
        appLogger.debug('User data: $userData');

        updateUserData(userData);
        return userData;
      },
    );
  }

  Future<void> fetchUserData() async {
    final result = await ref.read(lanternServiceProvider).fetchUserData();
    result.fold(
      (failure) {
        appLogger.error(
            'Error fetching user data: ${failure.localizedErrorMessage}');
      },
      (userData) {
        appLogger.debug('Fetched user data: $userData');
        updateUserData(userData);
      },
    );
  }

  void updateUserData(UserResponse userData) {
    state = AsyncValue.data(userData);
    if (!userData.legacyUserData.isPro()) {
      resetServerLocation();
    }
    sl<LocalStorageService>().saveUser(userData.toEntity());
  }

  /// Resets the server location to default.
  /// if user logs out or downgrade to free plan
  /// we need to reset the server location set to smart location
  void resetServerLocation() {
    final serverLocation = ref.read(serverLocationNotifierProvider);
    if (serverLocation.serverType.toServerLocationType ==
        ServerLocationType.lanternLocation) {
      appLogger.debug(
          "User is not Pro. Resetting server location to default (Fastest Country).");
      ref
          .read(serverLocationNotifierProvider.notifier)
          .updateServerLocation(initialServerLocation());
    }
  }

  /// Clear any user-specific data upon logout.
  /// Updates server location to fastest.
  /// Fetches available servers again.
  void clearLogoutData() {
    ref.read(referralNotifierProvider.notifier).resetReferral();
    ref.read(appSettingNotifierProvider.notifier).setUserLoggedIn(false);
  }
}
