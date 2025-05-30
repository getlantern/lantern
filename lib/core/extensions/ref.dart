import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

extension UserLevelExtension on WidgetRef {
  bool get isUserPro => watch(homeNotifierProvider.select(
        (user) => user.maybeWhen(
          data: (user) => user.legacyUserData.userLevel == 'pro',
          orElse: () => false,
        ),
      ));
}
