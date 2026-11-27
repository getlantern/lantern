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
    this.ringPadding = EdgeInsets.zero,
  });

  final VoidCallback? onActivate;
  final Widget child;
  final BorderRadius? borderRadius;

  /// False when [child] already handles taps itself (e.g. a toggle switch).
  final bool handlesTap;

  /// Room around [child] for the ring, so it sits outside the child instead
  /// of over its edge (a toggle's track, say). The ring is 3px of it.
  final EdgeInsets ringPadding;

  @override
  State<AppFocusable> createState() => _AppFocusableState();
}

class _AppFocusableState extends State<AppFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: widget.ringPadding,
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

/// The TV shell's focus ring, for widgets that are not an [AppFocusable]:
/// the same 3px onSurface line.
BorderSide tvFocusRingBorder(BuildContext context) =>
    BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 3);

/// A Material button style that draws [tvFocusRingBorder] while focused,
/// only in the TV shell; elsewhere null, so the button keeps its own style.
ButtonStyle? tvFocusRingButtonStyle(BuildContext context) {
  if (!PlatformUtils.tvShellEnabled) return null;
  final ring = tvFocusRingBorder(context);
  return ButtonStyle(
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused) ? ring : null,
    ),
  );
}

/// Marks a control the TV shell skips when it gives a screen its first
/// focus (a back or close button): still reachable with the D-pad, but a
/// screen opens on its first row or primary action.
class TvNotInitialFocus extends StatelessWidget {
  const TvNotInitialFocus({super.key, required this.child});

  final Widget child;

  /// Whether [node] sits under a [TvNotInitialFocus].
  static bool skips(FocusNode node) =>
      node.context?.findAncestorWidgetOfExactType<TvNotInitialFocus>() !=
      null;

  @override
  Widget build(BuildContext context) => child;
}

/// Draws [tvFocusRingBorder] over [builder]'s widget while the focus node
/// it hands the builder (to give an InkWell or ListTile as its focusNode)
/// has primary focus, only in the TV shell; elsewhere the widget is
/// unchanged. Primary focus, not subtree focus: a row whose trailing toggle
/// has focus shows the toggle's ring alone.
class TvFocusRing extends StatefulWidget {
  const TvFocusRing({super.key, required this.builder, this.borderRadius});

  final Widget Function(BuildContext context, FocusNode node) builder;
  final BorderRadius? borderRadius;

  @override
  State<TvFocusRing> createState() => _TvFocusRingState();
}

class _TvFocusRingState extends State<TvFocusRing> {
  final _node = FocusNode(debugLabel: 'TvFocusRing');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _node.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _node.hasPrimaryFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.tvShellEnabled) {
      return widget.builder(context, _node);
    }
    return Container(
      foregroundDecoration: BoxDecoration(
        border: _focused
            ? Border.fromBorderSide(tvFocusRingBorder(context))
            : null,
        borderRadius: widget.borderRadius,
      ),
      child: widget.builder(context, _node),
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
