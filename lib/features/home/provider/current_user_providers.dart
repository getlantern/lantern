import 'package:lantern/core/models/user_pro_ext.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

part 'current_user_providers.g.dart';

@Riverpod(keepAlive: true)
UserResponse? currentUser(Ref ref) {
  return ref.watch(homeProvider).value;
}

@Riverpod(keepAlive: true)
bool isUserProFromCore(Ref ref) {
  final user = ref.watch(currentUserProvider);
  return user?.legacyUserData.isPro ?? false;
}

@Riverpod(keepAlive: true)
String userEmailFromCore(Ref ref) {
  final user = ref.watch(currentUserProvider);
  return user?.legacyUserData.email ?? '';
}
