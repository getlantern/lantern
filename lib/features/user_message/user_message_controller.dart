import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/user_message.dart';
import 'package:lantern/features/user_message/user_message_repository.dart';

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
  late UserMessageRepository _repository;
  int _loadGeneration = 0;

  @override
  UserMessageState build() {
    _repository = ref.watch(userMessageRepositoryProvider);
    final subscription = _repository.messageAvailable.listen(
      (_) => unawaited(loadCurrent()),
      onError: (_) {},
    );
    ref.onDispose(subscription.cancel);
    Future.microtask(loadCurrent);
    return const UserMessageState();
  }

  /// Loads Radiance's pending message. The generation check keeps a slower,
  /// older request from overwriting the latest result.
  Future<void> loadCurrent() async {
    final generation = ++_loadGeneration;
    try {
      final message = await _repository.current();
      if (generation != _loadGeneration || state.displayedThisSession) return;
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
    await loadCurrent();
    try {
      await _repository.refresh();
    } on Object {
      // The normal Radiance poll will try again.
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
    state = state.copyWith(
      pending: null,
      presentationClaimed: false,
      displayedThisSession: true,
    );
    try {
      await _repository.acknowledge(displayId);
    } on Object {
      // Keep the one-per-session rule. Radiance can retry next session.
    }
  }
}

final userMessageControllerProvider =
    NotifierProvider<UserMessageController, UserMessageState>(
      UserMessageController.new,
    );
