import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Whether the Unbounded tab is on screen. Home sets it from its
/// TabController; the globe uses it to pause its tickers, since TabBarView
/// keeps off-screen tabs mounted and animating. Defaults to true so the globe
/// runs wherever nothing wires the signal.
final actionModeTabVisibleProvider =
    NotifierProvider<ActionModeTabVisible, bool>(ActionModeTabVisible.new);

class ActionModeTabVisible extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool visible) => state = visible;
}
