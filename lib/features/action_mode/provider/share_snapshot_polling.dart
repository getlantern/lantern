import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// Whether the backend sends sharing snapshots every second rather than every
/// 30 seconds. Each one wakes Go, the platform layer and Dart, so the fast
/// rate runs only while sharing or while the Unbounded tab is on screen in a
/// foreground app. Sharing keeps it on for the live tray count and speed.
/// Home keeps this alive.
final shareSnapshotPollingProvider =
    NotifierProvider<ShareSnapshotPolling, bool>(ShareSnapshotPolling.new);

class ShareSnapshotPolling extends Notifier<bool> {
  AppLifecycleState? _lifecycle;
  // Calls are chained so a quick off/on cannot reach the backend reordered.
  Future<void> _pending = Future.value();
  // Only the latest request may undo state after a failure.
  int _generation = 0;
  Timer? _retry;
  @visibleForTesting
  Duration retryDelay = const Duration(seconds: 2);

  @override
  bool build() {
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    final lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        _lifecycle = s;
        _update();
      },
    );
    ref.onDispose(() {
      lifecycle.dispose();
      _retry?.cancel();
    });
    ref.listen(actionModeTabVisibleProvider, (_, _) => _update());
    ref.listen(shareProvider.select((s) => s.active), (_, _) => _update());
    // The backend starts at the idle rate.
    Future.microtask(_update);
    return false;
  }

  bool _wanted() {
    if (ref.read(shareProvider).active) return true;
    final foreground = switch (_lifecycle) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
    return foreground && ref.read(actionModeTabVisibleProvider);
  }

  void _update() {
    if (!ref.mounted) return;
    final on = _wanted();
    if (on == state) return;
    state = on;
    _retry?.cancel();
    final generation = ++_generation;
    final service = ref.read(lanternServiceProvider);
    _pending = _pending.then((_) async {
      final result = await service.setSnapshotPolling(on);
      // The core may not be up yet: try again until the backend agrees.
      if (result.isLeft() && ref.mounted && generation == _generation) {
        state = !on;
        _retry = Timer(retryDelay, _update);
      }
    });
  }
}
