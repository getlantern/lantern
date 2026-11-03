import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/utils/platform_utils.dart';

/// Tap target that a D-pad or keyboard can reach: select, Enter or Space
/// activate it, and a ring is drawn over [child] while it has focus.
class AppFocusable extends StatefulWidget {
  const AppFocusable({
    super.key,
    required this.onActivate,
    required this.child,
    this.borderRadius,
    this.handlesTap = true,
  });

  final VoidCallback? onActivate;
  final Widget child;
  final BorderRadius? borderRadius;

  /// False when [child] already handles taps itself (e.g. a toggle switch).
  final bool handlesTap;

  @override
  State<AppFocusable> createState() => _AppFocusableState();
}

class _AppFocusableState extends State<AppFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      // Drawn over the child so focus never shifts the layout. Always set,
      // since adding or removing it would remount the child and drop its state.
      foregroundDecoration: BoxDecoration(
        border: _focused
            ? Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 3,
              )
            : null,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );
    return FocusableActionDetector(
      enabled: widget.onActivate != null,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      // Enter activates this target even inside a form that maps Enter to submit.
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: widget.handlesTap
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onActivate,
              child: child,
            )
          : child,
    );
  }
}

/// Focuses the first control of a sheet or dialog that just opened, so a TV
/// remote can act on it without a first arrow press.
void focusFirstOnTv(BuildContext context) {
  if (!PlatformUtils.isTv) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    // Builders rerun on rebuilds; leave focus alone once the user has moved it.
    final scope = FocusScope.of(context, createDependency: false);
    if (scope.focusedChild == null) scope.nextFocus();
  });
}
