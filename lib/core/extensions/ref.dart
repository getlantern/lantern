import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';

final isUserProProvider = Provider<bool>((ref) {
  return ref.watch(
    homeProvider.select(
      (value) => value.value?.legacyUserData.userLevel == 'pro',
    ),
  );
});

final isUserExpiredProvider = Provider<bool>((ref) {
  return ref.watch(
    homeProvider.select(
      (value) => value.value?.legacyUserData.userLevel == 'expired',
    ),
  );
});

final userEmailProvider = Provider<String>((ref) {
  return ref.watch(
    homeProvider.select(
      (value) => value.value?.legacyUserData.email ?? '',
    ),
  );
});

final isPrivateServerFoundProvider = Provider<bool>((ref) {
  final privateServersAsync = ref.watch(availableServersProvider);
  return privateServersAsync.maybeWhen(
    data: (servers) => servers.user.locations.values.isNotEmpty,
    orElse: () => false,
  );
});
