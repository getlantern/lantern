import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/features/user_message/user_message_action_dispatcher.dart';
import 'package:lantern/features/user_message/user_message_controller.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';
import 'package:loader_overlay/loader_overlay.dart';

typedef UserMessageClock = DateTime Function();
typedef CriticalOverlayCheck = bool Function(BuildContext context);

class UserMessageHost extends ConsumerStatefulWidget {
  const UserMessageHost({
    required this.child,
    required this.routeObserver,
    required this.actionDispatcher,
    required this.enabled,
    this.now,
    this.criticalOverlayVisible,
    this.retryInterval = const Duration(milliseconds: 250),
    super.key,
  });

  static const bodyKey = Key('user_message.snackbar.body');
  static const actionKey = Key('user_message.snackbar.action');
  static const closeKey = Key('user_message.snackbar.close');

  final Widget child;
  final UserMessageRouteObserver routeObserver;
  final UserMessageActionDispatcher actionDispatcher;
  final bool enabled;
  final UserMessageClock? now;
  final CriticalOverlayCheck? criticalOverlayVisible;
  final Duration retryInterval;

  @override
  ConsumerState<UserMessageHost> createState() => _UserMessageHostState();
}

class _UserMessageHostState extends ConsumerState<UserMessageHost>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _attemptScheduled = false;
  bool _active = true;
  Timer? _retryTimer;
  _UserMessagePresentation? _presentation;
  late final UserMessageController _controller;

  DateTime get _now => (widget.now?.call() ?? DateTime.now()).toUtc();

  @override
  void initState() {
    super.initState();
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _controller = ref.read(userMessageControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    widget.routeObserver.changes.addListener(_scheduleAttempt);
  }

  @override
  void didUpdateWidget(UserMessageHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeObserver != widget.routeObserver) {
      oldWidget.routeObserver.changes.removeListener(_scheduleAttempt);
      widget.routeObserver.changes.addListener(_scheduleAttempt);
    }
    if (oldWidget.enabled != widget.enabled) {
      _scheduleAttempt();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.onForegrounded());
      _scheduleAttempt();
    } else {
      _dismissForUnsafeState();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(userMessageControllerProvider);
    _scheduleAttempt();
    final presentation = _presentation;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (presentation != null) _messageSurface(presentation),
      ],
    );
  }

  void _scheduleAttempt() {
    if (!mounted || !_active || _attemptScheduled) return;
    _attemptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptScheduled = false;
      if (!mounted || !_active) return;
      final presentation = _presentation;
      if (presentation != null) {
        if (!_isSafeToPresent()) _dismissForUnsafeState();
        return;
      }
      _attemptPresentation();
    });
  }

  bool _isSafeToPresent() {
    if (!_active ||
        !widget.enabled ||
        _lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    if (!widget.routeObserver.isReadyForMessages) return false;
    final overlayVisible =
        widget.criticalOverlayVisible?.call(context) ??
        context.loaderOverlay.visible;
    if (overlayVisible) return false;
    return true;
  }

  void _attemptPresentation() {
    if (_presentation != null) return;
    final state = ref.read(userMessageControllerProvider);
    if (state.displayedThisSession || state.pending == null) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    if (!_isSafeToPresent()) {
      if (widget.enabled &&
          _lifecycleState == AppLifecycleState.resumed &&
          widget.routeObserver.isReadyForMessages) {
        _retryTimer ??= Timer(widget.retryInterval, () {
          _retryTimer = null;
          _scheduleAttempt();
        });
      } else {
        _retryTimer?.cancel();
        _retryTimer = null;
      }
      return;
    }

    final message = _controller.claimForPresentation(_now);
    if (message == null) return;
    final presentation = _UserMessagePresentation(message);
    setState(() => _presentation = presentation);

    final untilExpiration = message.expiresAt.difference(_now);
    if (untilExpiration <= Duration.zero) {
      _closePresentation(presentation);
      return;
    }
    presentation.expirationTimer = Timer(
      untilExpiration,
      () => _closePresentation(presentation),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onVisible(presentation),
    );
  }

  Widget _messageSurface(_UserMessagePresentation presentation) {
    final message = presentation.message;
    final action = message.action;
    return Positioned(
      left: 16,
      right: 16,
      top: 0,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: double.infinity,
            child: Material(
              key: ValueKey('user_message.snackbar.${message.displayId}'),
              elevation: 6,
              color: context.bgSnackbar,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: defaultPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                        ),
                        child: SingleChildScrollView(
                          child: Semantics(
                            liveRegion: true,
                            label: message.body,
                            excludeSemantics: true,
                            child: Text(
                              message.body,
                              key: UserMessageHost.bodyKey,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: context.textInverse),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (action != null && message.buttonLabel != null)
                      KeyedSubtree(
                        key: UserMessageHost.actionKey,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: context.textInverseColor,
                          ),
                          onPressed: () {
                            unawaited(widget.actionDispatcher.dispatch(action));
                            _closePresentation(presentation);
                          },
                          child: Text(message.buttonLabel!),
                        ),
                      ),
                    Semantics(
                      label: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      button: true,
                      child: ExcludeSemantics(
                        child: IconButton(
                          key: UserMessageHost.closeKey,
                          icon: const Icon(Icons.close),
                          color: context.textInverse,
                          onPressed: () => _closePresentation(presentation),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onVisible(_UserMessagePresentation presentation) {
    if (!mounted ||
        !identical(_presentation, presentation) ||
        !_isSafeToPresent() ||
        presentation.message.isExpiredAt(_now)) {
      _closePresentation(presentation);
      return;
    }
    presentation.visible = true;
    presentation.expirationTimer?.cancel();
    presentation.dismissalTimer = Timer(
      const Duration(seconds: 10),
      () => _closePresentation(presentation),
    );
    unawaited(_controller.markPresented(presentation.message.displayId));
  }

  void _closePresentation(_UserMessagePresentation presentation) {
    if (!mounted || !identical(_presentation, presentation)) return;
    presentation.expirationTimer?.cancel();
    presentation.dismissalTimer?.cancel();
    final shouldReleaseClaim = !presentation.visible;
    setState(() => _presentation = null);
    if (shouldReleaseClaim) {
      _controller.releaseClaim(presentation.message.displayId, _now);
    }
    _scheduleAttempt();
  }

  void _dismissForUnsafeState() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final presentation = _presentation;
    if (presentation == null) return;
    _closePresentation(presentation);
  }

  @override
  void deactivate() {
    _active = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    final presentation = _presentation;
    _presentation = null;
    if (presentation != null) {
      presentation.expirationTimer?.cancel();
      presentation.dismissalTimer?.cancel();
      final shouldReleaseClaim = !presentation.visible;
      final releaseAt = _now;
      Future.microtask(() {
        if (shouldReleaseClaim) {
          _controller.releaseClaim(presentation.message.displayId, releaseAt);
        }
      });
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    _scheduleAttempt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.routeObserver.changes.removeListener(_scheduleAttempt);
    _retryTimer?.cancel();
    _presentation?.expirationTimer?.cancel();
    _presentation?.dismissalTimer?.cancel();
    super.dispose();
  }
}

class _UserMessagePresentation {
  _UserMessagePresentation(this.message);

  final UserMessage message;
  Timer? expirationTimer;
  Timer? dismissalTimer;
  bool visible = false;
}
