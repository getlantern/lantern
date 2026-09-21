import 'dart:async';

import 'package:flutter/widgets.dart';
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
  Completer<bool>? availability;
  Exception? failure;
  int availabilityChecks = 0;
  int requests = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return availability?.future ?? available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) => throw UnimplementedError();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const required = RatingPromptService.requiredSessions;
  const minLength = RatingPromptService.minSessionDuration;

  late _FakeStorage storage;
  late DateTime now;
  late RatingPromptService svc;
  late _FakeReview review;
  late bool storeBuild;

  setUp(() {
    storage = _FakeStorage();
    review = _FakeReview();
    storeBuild = false;
    now = DateTime.utc(2026, 9, 15, 12);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    svc = RatingPromptService(
      storage,
      review: review,
      now: () => now,
      isStoreBuild: () => storeBuild,
    );
  });

  Future<void> session({
    Duration length = minLength,
    bool byUser = true,
  }) async {
    await svc.onConnected();
    now = now.add(length);
    await (byUser ? svc.onUserDisconnected() : svc.onDisconnected());
  }

  test(
    'counts qualifying sessions and retries when the prompt is unavailable',
    () async {
      for (var i = 0; i < required - 1; i++) {
        await session();
      }
      expect(svc.sessions, required - 1);

      await session();
      expect(svc.sessions, required);
      await session();
      expect(svc.sessions, required);
      expect(review.availabilityChecks, 0);
    },
  );

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
    svc = RatingPromptService(storage, now: () => now);
    await svc.onConnected();
    now = now.add(minLength ~/ 2);
    await svc.onUserDisconnected();
    expect(svc.sessions, required > 1 ? 1 : 0);
  });

  test('requests a review at the threshold and resets after success', () async {
    storeBuild = true;
    for (var i = 0; i < required - 1; i++) {
      await session();
    }
    expect(review.requests, 0);
    await session();
    expect(review.requests, 1);
    expect(svc.sessions, 0);
  });

  test('persists the threshold before waiting for the store', () async {
    storeBuild = true;
    for (var i = 0; i < required - 1; i++) {
      await session();
    }
    review.availability = Completer<bool>();
    final pending = session();
    await Future<void>.delayed(Duration.zero);
    expect(review.availabilityChecks, 1);
    expect(RatingPromptService(storage).sessions, required);
    review.availability!.complete(false);
    await pending;
  });

  test('unavailable reviews retain progress for the next session', () async {
    storeBuild = true;
    review.available = false;
    for (var i = 0; i < required; i++) {
      await session();
    }
    expect(review.requests, 0);
    expect(svc.sessions, required);
    review.available = true;
    await session();
    expect(review.requests, 1);
    expect(svc.sessions, 0);
  });

  test('failed review requests retain progress and can retry', () async {
    storeBuild = true;
    review.failure = Exception('store unavailable');
    for (var i = 0; i < required; i++) {
      await session();
    }
    expect(review.requests, 1);
    expect(svc.sessions, required);
    review.failure = null;
    await session();
    expect(review.requests, 2);
    expect(svc.sessions, 0);
  });

  test(
    'background disconnects keep the threshold for a later session',
    () async {
      storeBuild = true;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      for (var i = 0; i < required; i++) {
        await session();
      }
      expect(review.requests, 0);
      expect(svc.sessions, required);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await session();
      expect(review.requests, 1);
      expect(svc.sessions, 0);
    },
  );

  test(
    'does not request if backgrounded while checking availability',
    () async {
      storeBuild = true;
      review.availability = Completer<bool>();
      final request = svc.requestReview();
      expect(review.availabilityChecks, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      review.availability!.complete(true);
      expect(await request, isFalse);
      expect(review.requests, 0);
    },
  );
}
