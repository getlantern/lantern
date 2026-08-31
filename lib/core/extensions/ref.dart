import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/models/pro_renewal.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';

export 'package:lantern/core/models/pro_renewal.dart';

final isUserProProvider = Provider<bool>((ref) {
  return ref.watch(
    homeProvider.select((value) => value.value?.legacyUserData.isPro ?? false),
  );
});

final isUserExpiredProvider = Provider<bool>((ref) {
  return ref.watch(
    homeProvider.select(
      (value) => value.value?.legacyUserData.isExpired ?? false,
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

/// Escalating renewal state for one-time Pro purchases (engineering#3845),
/// derived from the same user data as [isUserProProvider]. Drives the home
/// banner, the account expiration card, and the day-of popup.
final proRenewalProvider = Provider<ProRenewalInfo>((ref) {
  final user = ref.watch(
    homeProvider.select((value) => value.value?.legacyUserData),
  );
  if (user == null) return ProRenewalInfo.none;

  if (user.isExpired) {
    final expiredOn = user.lastExpiredOn > 0
        ? user.lastExpiredOn
        : user.expiration;
    return ProRenewalInfo(
      ProRenewalState.expired,
      expiredOn > 0 ? _toLocalDate(expiredOn) : null,
      0,
    );
  }

  // Only one-time purchases escalate; auto-renewing subscriptions renew on
  // their own, so nagging would be wrong (and the store manages lapses).
  if (!user.isPro || user.expiration <= 0 || user.subscriptionData.autoRenew) {
    return ProRenewalInfo.none;
  }

  final end = _toLocalDate(user.expiration);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final daysLeft = endDay.difference(today).inDays;

  if (daysLeft < 0) {
    return ProRenewalInfo(ProRenewalState.expired, end, daysLeft);
  }
  if (daysLeft == 0) {
    return ProRenewalInfo(ProRenewalState.expiresToday, end, 0);
  }
  if (daysLeft <= 7) {
    return ProRenewalInfo(ProRenewalState.withinWeek, end, daysLeft);
  }
  return ProRenewalInfo.none;
});

DateTime _toLocalDate(int unixSeconds) => DateTime.fromMillisecondsSinceEpoch(
  unixSeconds * 1000,
  isUtc: true,
).toLocal();

final isPrivateServerFoundProvider = Provider<bool>((ref) {
  final privateServersAsync = ref.watch(availableServersProvider);
  return privateServersAsync.maybeWhen(
    data: (servers) => servers.hasUserServers,
    orElse: () => false,
  );
});
