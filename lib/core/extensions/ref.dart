import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

final isUserProProvider = Provider<bool>((ref) {
  return ref.watch(
    homeProvider.select(
          (value) => value.value?.legacyUserData.userLevel == 'pro',
    ),
  );
});