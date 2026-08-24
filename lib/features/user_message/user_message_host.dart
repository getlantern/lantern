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
    return widget.child;
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
    return ScaffoldMessenger.maybeOf(context) != null;
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      _controller.releaseClaim(message.displayId, _now);
      return;
    }

    late final _UserMessagePresentation presentation;
    final feature = messenger.showSnackBar(
      _snackBar(message, () => _onVisible(presentation)),
    );
    presentation = _UserMessagePresentation(message, feature, messenger);
    _presentation = presentation;

    // Register cleanup before checking expiration. The clock can advance after
    // the controller grants the claim, and removing the snackbar must always
    // release it.
    unawaited(
      feature.closed.then((_) {
        if (!mounted || !identical(_presentation, presentation)) return;
        presentation.expirationTimer?.cancel();
        if (!presentation.visible) {
          _controller.releaseClaim(message.displayId, _now);
        }
        _presentation = null;
        _scheduleAttempt();
      }),
    );

    final untilExpiration = message.expiresAt.difference(_now);
    if (untilExpiration <= Duration.zero) {
      _expireBeforePresentation(presentation);
      return;
    }
    presentation.expirationTimer = Timer(
      untilExpiration,
      () => _expireBeforePresentation(presentation),
    );
  }

  SnackBar _snackBar(UserMessage message, VoidCallback onVisible) {
    final action = message.action;
    return SnackBar(
      key: ValueKey('user_message.snackbar.${message.displayId}'),
      behavior: SnackBarBehavior.floating,
      padding: defaultPadding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: context.bgSnackbar,
      showCloseIcon: true,
      closeIconColor: context.textInverse,
      duration: const Duration(seconds: 10),
      onVisible: onVisible,
      content: ConstrainedBox(
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textInverse),
            ),
          ),
        ),
      ),
      action: action == null || message.buttonLabel == null
          ? null
          : SnackBarAction(
              key: UserMessageHost.actionKey,
              label: message.buttonLabel!,
              onPressed: () =>
                  unawaited(widget.actionDispatcher.dispatch(action)),
            ),
    );
  }

  void _onVisible(_UserMessagePresentation presentation) {
    if (!mounted || !identical(_presentation, presentation)) return;
    if (presentation.message.isExpiredAt(_now)) {
      _expireBeforePresentation(presentation);
      return;
    }
    presentation.visible = true;
    presentation.expirationTimer?.cancel();
    unawaited(_controller.markPresented(presentation.message.displayId));
  }

  void _expireBeforePresentation(_UserMessagePresentation presentation) {
    if (!mounted || !identical(_presentation, presentation)) return;
    if (presentation.visible) return;
    presentation.messenger.removeCurrentSnackBar();
  }

  void _dismissForUnsafeState() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final presentation = _presentation;
    if (presentation == null) return;
    presentation.expirationTimer?.cancel();
    presentation.messenger.removeCurrentSnackBar();
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
      final shouldReleaseClaim = !presentation.visible;
      final releaseAt = _now;
      Future.microtask(() {
        if (presentation.messenger.mounted) {
          presentation.messenger.removeCurrentSnackBar();
        }
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
    super.dispose();
  }
}

class _UserMessagePresentation {
  _UserMessagePresentation(this.message, this.feature, this.messenger);

  final UserMessage message;
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> feature;
  final ScaffoldMessengerState messenger;
  Timer? expirationTimer;
  bool visible = false;
}
