import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:lantern/core/common/common.dart' show isStoreVersion;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/logger_service.dart';

/// Requests a store review after five sessions of at least 30 minutes,
/// each ended by the user from the app. Store installs only.
class RatingPromptService {
  RatingPromptService(
    this._storage, {
    InAppReview? review,
    DateTime Function()? now,
    bool Function() isStoreBuild = isStoreVersion,
  }) : _review = review ?? InAppReview.instance,
       _now = now ?? DateTime.now,
       _isStoreBuild = isStoreBuild;

  static const int requiredSessions = 5;
  static const Duration minSessionDuration = Duration(minutes: 30);

  static const _sessionsKey = 'rating_prompt_sessions';
  static const _connectedAtKey = 'rating_prompt_connected_at';

  final LocalStorageService _storage;
  final InAppReview _review;
  final DateTime Function() _now;
  final bool Function() _isStoreBuild;

  /// Qualifying sessions since the last successful review request.
  int get sessions => int.tryParse(_storage.getString(_sessionsKey) ?? '') ?? 0;

  DateTime? get _connectedAt {
    final ms = int.tryParse(_storage.getString(_connectedAtKey) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Persisted so the session survives the app being killed mid-connection.
  Future<void> onConnected() async {
    if (_connectedAt != null) return;
    await _storage.setString(
      _connectedAtKey,
      _now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> onDisconnected() => _storage.remove(_connectedAtKey);

  Future<void> onUserDisconnected() async {
    final startedAt = _connectedAt;
    await onDisconnected();
    if (startedAt == null) {
      appLogger.info('Rating prompt: no session start recorded, ignoring');
      return;
    }
    final duration = _now().difference(startedAt);
    if (duration < minSessionDuration) {
      appLogger.info(
        'Rating prompt: session too short (${duration.inSeconds}s < '
        '${minSessionDuration.inSeconds}s), ignoring',
      );
      return;
    }

    final count = (sessions + 1).clamp(0, requiredSessions);
    appLogger.info('Rating prompt: session $count/$requiredSessions');
    // Persist first: the app can be closed while the native review UI is open.
    await _storage.setString(_sessionsKey, count.toString());
    if (count < requiredSessions) return;
    // Keep the threshold if unavailable or backgrounded; the next session retries.
    if (await requestReview()) {
      await _storage.remove(_sessionsKey);
    }
  }

  /// The store decides whether a successful request actually shows a prompt.
  Future<bool> requestReview() async {
    try {
      if (!_isStoreBuild()) {
        appLogger.info('Rating prompt: skipped, not a store build');
        return false;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return false;
      }
      if (!await _review.isAvailable()) {
        appLogger.info('Rating prompt: in-app review not available');
        return false;
      }
      // The app may have gone into the background while checking availability.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return false;
      }
      await _review.requestReview();
      appLogger.info('Rating prompt: review requested');
      return true;
    } catch (e, st) {
      appLogger.error('Rating prompt: requestReview failed', e, st);
      return false;
    }
  }
}
