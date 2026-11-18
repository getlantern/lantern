import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';

/// Reports whether the calling widget's route is on top. A route pushed over
/// Home, such as Settings, covers the Unbounded tab, so its snapshots can slow
/// down until Home is on top again.
void useReportHomeRouteCurrent(BuildContext context, WidgetRef ref) {
  final current = ModalRoute.of(context)?.isCurrent ?? true;
  useEffect(() {
    // Deferred: the first run is inside build, where Riverpod rejects writes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ref.read(homeRouteCurrentProvider.notifier).set(current);
    });
    return null;
  }, [current]);
}
