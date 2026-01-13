import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Hook that lets a widget react to app lifecycle transitions
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
