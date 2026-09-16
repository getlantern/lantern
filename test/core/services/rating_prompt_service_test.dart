import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
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

class _FakeReview implements InAppReview {
  bool available = true;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) => throw UnimplementedError();
}

void main() {
  late _FakeReview review;
  late DateTime now;
  late RatingPromptService svc;
  var storeBuild = true;

  setUp(() {
    review = _FakeReview();
    now = DateTime.utc(2026, 9, 15, 12);
    storeBuild = true;
    svc = RatingPromptService(
      _FakeStorage(),
      isStoreBuild: () => storeBuild,
      review: review,
      now: () => now,
    );
  });

  Future<void> session({
    Duration length = const Duration(minutes: 30),
    bool byUser = true,
  }) async {
    await svc.onConnected();
    now = now.add(length);
    await (byUser ? svc.onUserDisconnected() : svc.onDisconnected());
  }

  test(
    'requests review on the 5th qualifying session, then restarts',
    () async {
      for (var i = 0; i < 4; i++) {
        await session();
      }
      expect(review.requests, 0);
      expect(svc.sessions, 4);

      await session();
      expect(review.requests, 1);
      expect(svc.sessions, 0);

      for (var i = 0; i < 5; i++) {
        await session();
      }
      expect(review.requests, 2);
    },
  );

  test('short or non-user sessions do not count', () async {
    await session(length: const Duration(minutes: 29, seconds: 59));
    await session(byUser: false);
    expect(svc.sessions, 0);
  });

  test('non-store builds never call the store', () async {
    storeBuild = false;
    for (var i = 0; i < 5; i++) {
      await session();
    }
    expect(review.requests, 0);
  });

  test('unavailable review API is not called', () async {
    review.available = false;
    for (var i = 0; i < 5; i++) {
      await session();
    }
    expect(review.requests, 0);
  });

  test('session start survives a re-hydrated connected event', () async {
    await svc.onConnected();
    now = now.add(const Duration(minutes: 20));
    await svc.onConnected();
    now = now.add(const Duration(minutes: 10));
    await svc.onUserDisconnected();
    expect(svc.sessions, 1);
  });
}
