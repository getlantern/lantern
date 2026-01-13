import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Hook that lets a widget react to app lifecycle transitions.
///
/// The [onState] callback is invoked every time the app's [AppLifecycleState]
/// changes (for example when the app is resumed, paused, or detached). This
/// hook internally registers a [WidgetsBindingObserver] when the widget is
/// first built, and automatically removes the observer when the hook is
/// disposed (typically when the widget using this hook is unmounted), so no
/// manual cleanup is required.
///
/// Typical usage:
///
/// ```dart
/// class MyHookWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     useAppLifecycleListener((AppLifecycleState state) {
///       switch (state) {
///         case AppLifecycleState.resumed:
///           // App has come to the foreground.
///           break;
///         case AppLifecycleState.inactive:
///           // App is inactive (e.g. during a phone call).
///           break;
///         case AppLifecycleState.paused:
///           // App is not currently visible to the user, running in the background.
///           break;
///         case AppLifecycleState.detached:
///           // App is still hosted on a flutter engine but detached from any host views.
///           break;
///       }
///     });
///
///     return const SizedBox.shrink();
///   }
/// }
/// ```
void useAppLifecycleListener(void Function(AppLifecycleState state) onState) {
  final onStateRef = useRef<void Function(AppLifecycleState)>(onState);
  onStateRef.value = onState;

  useEffect(() {
    final observer = _LifecycleObserver((state) => onStateRef.value(state));
    WidgetsBinding.instance.addObserver(observer);
    return () => WidgetsBinding.instance.removeObserver(observer);
  }, const []);
}

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.onState);
  final void Function(AppLifecycleState) onState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onState(state);
}
