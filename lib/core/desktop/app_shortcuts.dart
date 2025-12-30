import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/desktop/app_intent.dart';

/// A widget that provides a shortcut for the Enter key to trigger a specified callback action.
class EnterKeyShortcut extends StatelessWidget {
  final Widget child;
  final VoidCallback? onEnter;
  final bool enabled;

  const EnterKeyShortcut({
    super.key,
    required this.child,
    required this.onEnter,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.enter): const EnterIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const EnterIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          EnterIntent: CallbackAction<EnterIntent>(
            onInvoke: (EnterIntent intent) {
              if (enabled && onEnter != null) {
                onEnter!();
              }
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}
