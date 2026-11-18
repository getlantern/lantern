import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// Whether the backend's once-a-second sharing snapshots are on. Each one
/// wakes Go, the platform layer and Dart, so they run only while something
/// shows their stats: the Unbounded tab in a foreground app, or, on desktop,
/// the tray's live peer count while sharing. Home keeps this alive.
final shareSnapshotPollingProvider =
    NotifierProvider<ShareSnapshotPolling, bool>(ShareSnapshotPolling.new);

class ShareSnapshotPolling extends Notifier<bool> {
  AppLifecycleState? _lifecycle;
  // Calls are chained so a quick off/on cannot reach the backend reordered.
  Future<void> _pending = Future.value();
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
    // The backend starts with polling off.
    Future.microtask(_update);
    return false;
  }

  bool _wanted() {
    final foreground = switch (_lifecycle) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
    if (foreground && ref.read(actionModeTabVisibleProvider)) return true;
    return PlatformUtils.isDesktop && ref.read(shareProvider).active;
  }

  void _update() {
    if (!ref.mounted) return;
    final on = _wanted();
    if (on == state) return;
    state = on;
    _retry?.cancel();
    if (!on) ref.read(shareProvider.notifier).snapshotsPaused();
    final service = ref.read(lanternServiceProvider);
    _pending = _pending.then((_) async {
      final result = await service.setSnapshotPolling(on);
      // The core may not be up yet: try again until the backend agrees.
      if (result.isLeft() && ref.mounted && state == on) {
        state = !on;
        _retry = Timer(retryDelay, _update);
      }
    });
  }
}
