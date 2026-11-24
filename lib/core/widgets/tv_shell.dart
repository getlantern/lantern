import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/extensions/ref.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/widgets/app_focusable.dart';
import 'package:lantern/core/widgets/lantern_logo.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

/// The TV two-panel shell, one per screen (lib/core/router/tv_route_builder.dart):
/// the logo and connect switch on the left, the screen on the right at phone
/// width. Being inside the route keeps the switch and the screen in one focus
/// scope, and lets sheets and dialogs dim the whole screen.
///
/// Focus: the screen's panel is its own [FocusScope], so Right from the switch
/// returns to the row the user left, and a closed sheet or dialog hands focus
/// back to its opener. Left from the panel's edge goes to the switch.
class TvShell extends ConsumerStatefulWidget {
  /// How long a screen that opens with only back, close or search controls
  /// (its list still loading) keeps looking for a row to land on.
  @visibleForTesting
  static Duration initialFocusWait = const Duration(seconds: 10);

  /// The clock the wait is measured on; tests advance it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  const TvShell({super.key, required this.routeName, required this.child});

  final String routeName;
  final Widget child;

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  final _leftScope = FocusScopeNode(debugLabel: 'TvShell.left');
  final _rightScope = FocusScopeNode(debugLabel: 'TvShell.right');
  final _switchNode = FocusNode(debugLabel: 'VPNSwitch');
  bool _wasCurrent = false;

  @override
  void initState() {
    super.initState();
    // Android starts in touch highlight mode, so no ring would show until
    // the first key press; a TV only has keys.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_wasCurrent) _restoreFocus();
    _wasCurrent = current;
  }

  @override
  void dispose() {
    _leftScope.dispose();
    _rightScope.dispose();
    _switchNode.dispose();
    super.dispose();
  }

  /// On first show, and whenever a route over this one closes: Flutter puts
  /// focus back on the row that opened it; when nothing real holds focus
  /// (the switch was disabled while covered, or the screen just opened),
  /// Home gets the switch and any other screen gets its first row.
  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = FocusManager.instance.primaryFocus;
      final inPanel =
          focused != null &&
          focused is! FocusScopeNode &&
          (focused.ancestors.contains(_rightScope) ||
              focused.ancestors.contains(_leftScope));
      if (inPanel) return;
      if (widget.routeName == Home.name) {
        _switchNode.requestFocus();
      } else {
        _focusRight();
      }
    });
  }

  /// The row the user left, or the panel's first row. A back, close or
  /// search button ([TvNotInitialFocus]) is skipped, except while a list is
  /// still loading, when one holds focus as a placeholder, and after the
  /// wait for that list runs out, when it stays the remembered focus.
  void _focusRight() {
    _rightScope.requestFocus();
    final remembered = _rightScope.focusedChild;
    if (remembered != null) {
      // The row the user left; unless it is the loading placeholder, which
      // may have a row to move to by now (on its original deadline).
      if (identical(remembered, _placeholder)) {
        _settleOnEligible(until: _placeholderDeadline);
      }
      return;
    }
    _rightScope.nextFocus();
    _settleOnEligible();
  }

  /// The marked control holding focus while nothing eligible exists yet
  /// (see [_settleOnEligible]); null once a row took focus or the user
  /// moved.
  FocusNode? _placeholder;
  DateTime? _placeholderDeadline;

  /// Moves past the controls marked [TvNotInitialFocus] to the first row.
  /// When only such controls exist yet, the arrow keeps focus as a
  /// placeholder and each frame looks again for a row, until one appears,
  /// the user moves, another route covers this one, or [initialFocusWait]
  /// runs out; focus is never moved while there is nowhere better to go.
  void _settleOnEligible({DateTime? until}) {
    // Focus moves apply in a microtask; settle them before looking.
    FocusManager.instance.applyFocusChangesIfNeeded();
    final placeholder = FocusManager.instance.primaryFocus;
    if (placeholder == null || !TvNotInitialFocus.skips(placeholder)) {
      _placeholder = null;
      return;
    }
    final deadline = until ?? TvShell.now().add(TvShell.initialFocusWait);
    final rowExists = _rightScope.traversalDescendants.any(
      (n) => !TvNotInitialFocus.skips(n),
    );
    if (rowExists && !TvShell.now().isAfter(deadline)) {
      // Past the marked controls (an arrow, a search icon) to the row.
      for (var i = 0; i < 3; i++) {
        final focused = FocusManager.instance.primaryFocus;
        if (focused == null || !TvNotInitialFocus.skips(focused)) break;
        focused.nextFocus();
        FocusManager.instance.applyFocusChangesIfNeeded();
      }
      _placeholder = null;
      return;
    }
    // Nothing eligible yet: focus stays where it is (moving it would only
    // cycle the marked controls' rings) and the next frame looks again,
    // until the deadline; after it the placeholder is the user's.
    if (TvShell.now().isAfter(deadline)) {
      _placeholder = null;
      return;
    }
    _placeholder = placeholder;
    _placeholderDeadline = deadline;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!identical(FocusManager.instance.primaryFocus, placeholder)) {
        // The user moved (or the switch took focus; Right brings it back
        // through _focusRight, which looks again).
        if (!identical(FocusManager.instance.primaryFocus, _switchNode)) {
          _placeholder = null;
        }
        return;
      }
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      _settleOnEligible(until: deadline);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final rightWidth = size.width - tvRightPanelX - tvSafeMarginH;
    final rightHeight = size.height - tvSafeMarginV;
    final animation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final textDirection = Directionality.of(context);

    final left = Padding(
      padding: const EdgeInsets.fromLTRB(
        tvSafeMarginH,
        tvSafeMarginV,
        0,
        tvSafeMarginV,
      ),
      child: SizedBox(
        width: tvLeftPanelWidth,
        child: FocusScope(
          node: _leftScope,
          child: Actions(
            actions: {
              DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
                onInvoke: (intent) {
                  if (intent.direction == TraversalDirection.right) {
                    _focusRight();
                  }
                  return null;
                },
              ),
            },
            child: Column(
              children: [
                LanternLogo(
                  isPro: ref.watch(isUserProProvider),
                  color: context.textPrimary,
                  widthFraction: 0.35,
                ),
                Expanded(
                  child: Center(
                    child: Transform.scale(
                      scale: 1.5,
                      child: VPNSwitch(
                        focusNode: _switchNode,
                        autofocusOnTv: false,
                      ),
                    ),
                  ),
                ),
                // Balances the logo so the switch sits on the panel's centre.
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );

    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: tvSafeMarginV),
      child: SizedBox(
        width: 1,
        height: size.height - 2 * tvSafeMarginV,
        child: ColoredBox(color: theme.colorScheme.outline),
      ),
    );

    // The panel runs to the bottom edge, so lists scroll off it. The bottom
    // safe margin is given as MediaQuery padding for a screen that wants its
    // list to end inside it; a list with its own padding reaches the edge.
    final right = Padding(
      padding: const EdgeInsets.only(top: tvSafeMarginV),
      child: SizedBox(
        width: rightWidth,
        height: rightHeight,
        child: FadeTransition(
          opacity: animation,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              size: Size(rightWidth, rightHeight),
              padding: mediaQuery.padding.copyWith(
                top: 0,
                bottom: tvSafeMarginV,
              ),
              viewPadding: mediaQuery.viewPadding.copyWith(
                top: 0,
                bottom: tvSafeMarginV,
              ),
            ),
            child: FocusScope(
              node: _rightScope,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(
                  requestFocusCallback: tvRequestFocus,
                ),
                child: Actions(
                  actions: {
                    DirectionalFocusIntent:
                        CallbackAction<DirectionalFocusIntent>(
                          onInvoke: (intent) {
                            final node = FocusManager.instance.primaryFocus;
                            if (node == null) return null;
                            final moved = node.focusInDirection(
                              intent.direction,
                            );
                            if (!moved &&
                                intent.direction == TraversalDirection.left) {
                              _switchNode.requestFocus();
                            }
                            return null;
                          },
                        ),
                  },
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The panels keep their places in right-to-left locales: the D-pad
    // hand-off (Left to the switch, Right back to the screen) and the sheet
    // anchor are physical, so the layout is too. Text keeps its direction.
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(textDirection: textDirection, child: left),
            const SizedBox(width: tvPanelGap),
            divider,
            const SizedBox(width: tvPanelGap),
            Directionality(textDirection: textDirection, child: right),
          ],
        ),
      ),
    );
  }
}

/// Focuses [node] and scrolls it into the safe area where the list has the
/// room (Flutter's default only brings it to the viewport's edge, which on
/// TV is the screen's edge); a list that ends right after its last row keeps
/// that row at the edge, so a screen adds trailing padding when it wants it.
void tvRequestFocus(
  FocusNode node, {
  ScrollPositionAlignmentPolicy? alignmentPolicy,
  double? alignment,
  Duration? duration,
  Curve? curve,
}) {
  node.requestFocus();
  final context = node.context;
  final renderObject = context?.findRenderObject();
  final viewport = renderObject == null
      ? null
      : RenderAbstractViewport.maybeOf(renderObject);
  final scrollable = context == null ? null : Scrollable.maybeOf(context);
  // The inset below is vertical: a horizontal scrollable (a carousel) gets
  // Flutter's own reveal.
  if (context == null ||
      renderObject == null ||
      viewport == null ||
      scrollable == null ||
      scrollable.position.axis != Axis.vertical) {
    FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
      node,
      alignmentPolicy: alignmentPolicy,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
    return;
  }
  // Enclosing scrollables (a list inside a page that scrolls): reveal the
  // node in each the way Flutter's own callback does, revealing the inner
  // scrollable's box in each outer viewport with the node as the target;
  // only the nearest one gets the safe-area inset below. Run once the
  // nearest list has moved, since that move changes where the row sits in
  // the outer viewports.
  void revealInOuter() {
    if (!renderObject.attached) return;
    var inner = scrollable;
    for (
      var outer = Scrollable.maybeOf(inner.context);
      outer != null;
      inner = outer, outer = Scrollable.maybeOf(outer.context)
    ) {
      final innerBox = inner.context.findRenderObject();
      if (innerBox == null) break;
      outer.position.ensureVisible(
        innerBox,
        targetRenderObject: renderObject,
        alignment: alignment ?? 1.0,
        alignmentPolicy:
            alignmentPolicy ?? ScrollPositionAlignmentPolicy.explicit,
        duration: duration ?? Duration.zero,
        curve: curve ?? Curves.ease,
      );
    }
  }

  final position = scrollable.position;
  final revealTop = viewport.getOffsetToReveal(renderObject, 0).offset;
  final revealBottom =
      viewport.getOffsetToReveal(renderObject, 1).offset + tvSafeMarginV;
  var target = position.pixels;
  if (position.pixels > revealTop) {
    target = revealTop;
  } else if (position.pixels < revealBottom) {
    target = revealBottom;
  }
  // Lists scroll by focus, so text after the last row (a version number, a
  // note) would never show: when nothing focusable follows [node] in this
  // list and the end of the list leaves the row's top in view, scroll to
  // the end.
  if (!_hasFocusableBelow(node, scrollable) &&
      position.maxScrollExtent > revealBottom &&
      position.maxScrollExtent <= revealTop) {
    target = position.maxScrollExtent;
  }
  // A control taller than the viewport less the inset: its top edge stays
  // in view rather than its bottom inset.
  if (target > revealTop) target = revealTop;
  target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
  if (target == position.pixels) {
    revealInOuter();
    return;
  }
  position
      .animateTo(
        target,
        duration: duration ?? const Duration(milliseconds: 150),
        curve: curve ?? Curves.easeInOut,
      )
      .then((_) => revealInOuter());
}

bool _hasFocusableBelow(FocusNode node, ScrollableState scrollable) {
  final scope = node.nearestScope;
  if (scope == null) return false;
  final bottom = node.rect.bottom;
  for (final other in scope.traversalDescendants) {
    if (identical(other, node)) continue;
    final context = other.context;
    if (context == null || Scrollable.maybeOf(context) != scrollable) continue;
    if (other.rect.top >= bottom) return true;
  }
  return false;
}
