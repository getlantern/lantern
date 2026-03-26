import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Tracks whether current VPN status transitions are likely settings-driven.
///
/// The VPN status stream does not include the origin/cause of transitions, so
/// we track expected settings-triggered reconnect windows here and let
/// [VpnNotifier] decide whether connection notifications should be shown.
final vpnTransitionOriginTrackerProvider = Provider<VpnTransitionOriginTracker>(
  (ref) {
    final tracker = VpnTransitionOriginTracker();
    ref.onDispose(tracker.dispose);
    return tracker;
  },
);

class VpnTransitionOriginTracker {
  int _activeScopes = 0;
  DateTime _settingsMutationUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isInSettingsMutationWindow {
    if (_activeScopes > 0) {
      return true;
    }
    return DateTime.now().isBefore(_settingsMutationUntil);
  }

  void beginSettingsMutation() {
    _activeScopes++;
  }

  void endSettingsMutation({
    Duration settleWindow = const Duration(seconds: 8),
  }) {
    if (_activeScopes > 0) {
      _activeScopes--;
    }

    final candidate = DateTime.now().add(settleWindow);
    if (candidate.isAfter(_settingsMutationUntil)) {
      _settingsMutationUntil = candidate;
    }
  }

  Future<T> runAsSettingsMutation<T>(
    Future<T> Function() operation, {
    Duration settleWindow = const Duration(seconds: 8),
  }) async {
    beginSettingsMutation();
    try {
      return await operation();
    } finally {
      endSettingsMutation(settleWindow: settleWindow);
    }
  }

  void dispose() {
    _activeScopes = 0;
    _settingsMutationUntil = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
