import 'package:in_app_review/in_app_review.dart';
import 'package:lantern/core/common/common.dart' show isStoreVersion;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/logger_service.dart';

/// Requests the native store rating prompt after the 5th session connected
/// for 30 minutes and disconnected by the user. Store installs only.
class RatingPromptService {
  RatingPromptService(
    this._storage, {
    InAppReview? review,
    DateTime Function()? now,
  }) : _review = review ?? InAppReview.instance,
       _now = now ?? DateTime.now;

  static const int requiredSessions = 5;
  static const Duration minSessionDuration = Duration(minutes: 30);

  static const _sessionsKey = 'rating_prompt_sessions';
  static const _connectedAtKey = 'rating_prompt_connected_at';

  final LocalStorageService _storage;
  final InAppReview _review;
  final DateTime Function() _now;

  /// Qualifying sessions since the last prompt.
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

    final count = sessions + 1;
    appLogger.info('Rating prompt: session $count/$requiredSessions');
    if (count < requiredSessions) {
      await _storage.setString(_sessionsKey, count.toString());
      return;
    }
    // Keep the counter at the threshold when the prompt could not be shown so
    // the next qualifying session retries instead of restarting from zero.
    // The OS rate-limits how often the prompt is actually displayed.
    if (await requestReview()) {
      await _storage.remove(_sessionsKey);
    } else {
      await _storage.setString(_sessionsKey, requiredSessions.toString());
    }
  }

  Future<bool> requestReview() async {
    if (!isStoreVersion()) {
      appLogger.info('Rating prompt: skipped, not a store build');
      return false;
    }
    try {
      if (!await _review.isAvailable()) {
        appLogger.info('Rating prompt: in-app review not available');
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
