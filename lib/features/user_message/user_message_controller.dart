import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/utils/latest_async_queue.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

const _unchangedPending = Object();

class UserMessageState {
  const UserMessageState({
    this.pending,
    this.presentationClaimed = false,
    this.displayedThisSession = false,
  });

  final UserMessage? pending;
  final bool presentationClaimed;
  final bool displayedThisSession;

  UserMessageState copyWith({
    Object? pending = _unchangedPending,
    bool? presentationClaimed,
    bool? displayedThisSession,
  }) {
    return UserMessageState(
      pending: identical(pending, _unchangedPending)
          ? this.pending
          : pending as UserMessage?,
      presentationClaimed: presentationClaimed ?? this.presentationClaimed,
      displayedThisSession: displayedThisSession ?? this.displayedThisSession,
    );
  }
}

class UserMessageController extends Notifier<UserMessageState> {
  late LanternCoreService _service;
  int _loadGeneration = 0;
  int _lifecycleGeneration = 0;
  late final _activityUpdates = LatestAsyncQueue<bool, void>(
    worker: _setActive,
    defaultResult: null,
  );
  bool _foreground = true;
  ({String displayId, String accountId})? _acknowledgment;
  Timer? _ackRetry;
  int _ackAttempts = 0;
  bool _ackInFlight = false;

  @override
  UserMessageState build() {
    _service = ref.watch(lanternServiceProvider);
    final subscription = _service
        .watchAppEvents()
        .where((event) => event.eventType == AppEvent.userMessageAvailable)
        .listen((_) => unawaited(loadCurrent()), onError: (_) {});
    ref.onDispose(subscription.cancel);
    ref.onDispose(() => _ackRetry?.cancel());
    // Pull any message Radiance already has, then wake its cloud fetch. The
    // explicit refresh matters when the native backend was already running or
    // first-run account creation finished just after the initial local read.
    Future.microtask(onForegrounded);
    return const UserMessageState();
  }

  /// Loads Radiance's pending message. The generation check keeps a slower,
  /// older request from overwriting the latest result.
  Future<void> loadCurrent() async {
    if (!ref.mounted ||
        state.displayedThisSession ||
        state.presentationClaimed) {
      return;
    }
    final generation = ++_loadGeneration;
    state = state.copyWith(pending: null);
    try {
      final message = _unwrap(await _service.currentUserMessage());
      if (!ref.mounted ||
          generation != _loadGeneration ||
          state.displayedThisSession) {
        return;
      }
      if (state.presentationClaimed) return;
      final now = DateTime.now().toUtc();
      state = state.copyWith(
        pending: message == null || message.isExpiredAt(now) ? null : message,
      );
    } on Object {
      // Radiance keeps the message for the next event or app session.
    }
  }

  /// Pulls local state first, then asks Radiance to check the server again.
  Future<void> onForegrounded() async {
    if (!ref.mounted) return;
    _foreground = true;
    final generation = ++_lifecycleGeneration;
    final current = loadCurrent();
    await _activityUpdates.enqueue(true);
    await current;
    if (!ref.mounted || generation != _lifecycleGeneration) return;
    unawaited(_acknowledgePresented());
    try {
      _unwrap(await _service.refreshUserMessages());
    } on Object {
      // The normal Radiance poll will try again.
    }
  }

  Future<void> onBackgrounded() async {
    _foreground = false;
    _lifecycleGeneration++;
    _ackRetry?.cancel();
    await _activityUpdates.enqueue(false);
  }

  Future<void> _setActive(bool active) async {
    if (!ref.mounted) return;
    try {
      _unwrap(await _service.setUserMessageActivity(active));
    } on Object {
      // A later lifecycle update will reconcile the native state.
    }
  }

  /// Reserves the pending message so rebuilds cannot present it twice.
  UserMessage? claimForPresentation(DateTime now) {
    if (state.displayedThisSession || state.presentationClaimed) return null;
    final message = state.pending;
    if (message == null) return null;
    if (message.isExpiredAt(now.toUtc())) {
      state = state.copyWith(pending: null);
      return null;
    }
    state = state.copyWith(presentationClaimed: true);
    return message;
  }

  void releaseClaim(String displayId, DateTime now) {
    if (!ref.mounted) return;
    if (state.displayedThisSession || !state.presentationClaimed) return;
    final pending = state.pending;
    if (pending?.displayId != displayId) return;
    state = state.copyWith(
      pending: pending!.isExpiredAt(now.toUtc()) ? null : pending,
      presentationClaimed: false,
    );
  }

  /// Consumes this app session before acknowledging the visible message.
  Future<void> markPresented(String displayId) async {
    if (state.displayedThisSession || !state.presentationClaimed) return;
    if (state.pending?.displayId != displayId) return;
    _acknowledgment = (
      displayId: displayId,
      accountId: state.pending!.accountId,
    );
    state = state.copyWith(
      pending: null,
      presentationClaimed: false,
      displayedThisSession: true,
    );
    await _acknowledgePresented();
  }

  Future<void> _acknowledgePresented() async {
    final acknowledgment = _acknowledgment;
    if (!ref.mounted ||
        !_foreground ||
        _ackInFlight ||
        acknowledgment == null ||
        _ackAttempts >= 3) {
      return;
    }
    _ackRetry?.cancel();
    _ackInFlight = true;
    _ackAttempts++;
    try {
      if (_ackAttempts > 1) {
        final current = _unwrap(await _service.currentUserMessage());
        if (!ref.mounted) return;
        if (current?.accountId != acknowledgment.accountId ||
            current?.displayId != acknowledgment.displayId) {
          _acknowledgment = null;
          return;
        }
      }
      _unwrap(
        await _service.acknowledgeUserMessage(
          acknowledgment.displayId,
          acknowledgment.accountId,
        ),
      );
      _acknowledgment = null;
    } on Object {
      if (ref.mounted && _foreground && _ackAttempts < 3) {
        _ackRetry = Timer(Duration(seconds: 1 << (_ackAttempts - 1)), () {
          unawaited(_acknowledgePresented());
        });
      }
    } finally {
      _ackInFlight = false;
    }
  }

  T _unwrap<T>(Either<Failure, T> result) {
    // Keep native failure details out of provider state and diagnostics.
    return result.fold(
      (_) => throw Exception('User-message request failed'),
      (value) => value,
    );
  }
}

final userMessageControllerProvider =
    NotifierProvider<UserMessageController, UserMessageState>(
      UserMessageController.new,
    );
