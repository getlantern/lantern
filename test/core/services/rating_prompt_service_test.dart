import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/rating_prompt_service.dart';

class _FakeStorage extends LocalStorageService {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// The store call itself is gated by [isStoreVersion], which is false under
/// `flutter test`, so these cover the session counting only.
void main() {
  const required = RatingPromptService.requiredSessions;
  const minLength = RatingPromptService.minSessionDuration;

  late _FakeStorage storage;
  late DateTime now;
  late RatingPromptService svc;

  setUp(() {
    storage = _FakeStorage();
    now = DateTime.utc(2026, 9, 15, 12);
    svc = RatingPromptService(storage, now: () => now);
  });

  Future<void> session({
    Duration length = minLength,
    bool byUser = true,
  }) async {
    await svc.onConnected();
    now = now.add(length);
    await (byUser ? svc.onUserDisconnected() : svc.onDisconnected());
  }

  test('counts qualifying sessions and resets on the last one', () async {
    for (var i = 0; i < required - 1; i++) {
      await session();
    }
    expect(svc.sessions, required - 1);

    await session();
    expect(svc.sessions, 0);
  });

  test('short or non-user sessions do not count', () async {
    await session(length: minLength - const Duration(seconds: 1));
    await session(byUser: false);
    expect(svc.sessions, 0);
  });

  test('every disconnect clears the session start', () async {
    await svc.onConnected();
    await svc.onDisconnected();
    await svc.onUserDisconnected();
    expect(storage.values, isEmpty);
  });

  test('session start survives a re-hydrated connected event', () async {
    await svc.onConnected();
    now = now.add(minLength ~/ 2);
    await svc.onConnected();
    now = now.add(minLength ~/ 2);
    await svc.onUserDisconnected();
    expect(svc.sessions, required > 1 ? 1 : 0);
  });
}
