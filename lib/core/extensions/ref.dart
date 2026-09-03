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

  // Only one-time purchases escalate; auto-renewing subscriptions renew on
  // their own, so nagging would be wrong (and the store manages lapses).
  // Note: expired users have isPro == false, so this check must not gate the
  // expired branch below on isPro.
  if (user.subscriptionData.autoRenew) return ProRenewalInfo.none;

  if (user.isExpired) {
    final expiredOn = user.lastExpiredOn > 0
        ? user.lastExpiredOn
        : user.expiration;
    if (expiredOn <= 0) {
      return ProRenewalInfo(ProRenewalState.expired, null, 0);
    }
    final end = _toLocalDate(expiredOn);
    return ProRenewalInfo(ProRenewalState.expired, end, _daysFromToday(end));
  }

  if (!user.isPro || user.expiration <= 0) return ProRenewalInfo.none;

  final end = _toLocalDate(user.expiration);
  final daysLeft = _daysFromToday(end);

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

/// Calendar days from today until [end]: 0 on the last day, negative once
/// past it.
int _daysFromToday(DateTime end) {
  // UTC date-only values keep the difference an exact multiple of 24h;
  // local midnights can be 23/25h apart across DST transitions.
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  return DateTime.utc(end.year, end.month, end.day).difference(today).inDays;
}

final isPrivateServerFoundProvider = Provider<bool>((ref) {
  final privateServersAsync = ref.watch(availableServersProvider);
  return privateServersAsync.maybeWhen(
    data: (servers) => servers.hasUserServers,
    orElse: () => false,
  );
});
