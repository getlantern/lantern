import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_user_providers.g.dart';

@Riverpod(keepAlive: true)
UserResponse? currentUser(Ref ref) {
  return ref.watch(homeProvider).value;
}
