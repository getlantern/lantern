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
    homeProvider.select((value) => value.value?.legacyUserData.email ?? ''),
  );
});

/// Nudges the user about their Pro renewal and shows the appropriate banner.
final proRenewalProvider = Provider<ProRenewalInfo>((ref) {
  final user = ref.watch(
    homeProvider.select((value) => value.value?.legacyUserData),
  );
  if (user == null) return ProRenewalInfo.none;

  // Auto-renewing subscriptions renew on their own, so skip them. Everyone
  // else (one-time purchases and canceled subscriptions) gets the nudge.
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
