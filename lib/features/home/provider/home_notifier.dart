import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pbserver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_notifier.g.dart';

@Riverpod()
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

  void updateUserData(UserResponse userData) {
    state = AsyncValue.data(userData);
    sl<LocalStorageService>().saveUser(userData.toEntity());
  }

  bool get isProUser {
    final data = state.valueOrNull;
    return data?.legacyUserData.userStatus == 'pro';
  }
}
