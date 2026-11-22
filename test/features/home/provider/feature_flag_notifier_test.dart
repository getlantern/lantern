import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// Answers each featureFlag call with the next completer, in call order.
class _Service implements LanternService {
  final answers = <Completer<Either<Failure, String>>>[];

  @override
  Future<Either<Failure, String>> featureFlag() {
    final c = Completer<Either<Failure, String>>();
    answers.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a slower fetch never replaces a newer one', () async {
    final service = _Service();
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(featureFlagProvider);
    final notifier = container.read(featureFlagProvider.notifier);
    final second = notifier.fetchFeatureFlags();
    expect(service.answers, hasLength(2));

    service.answers[1].complete(right('{"helper_volunteer":false}'));
    await second;
    service.answers[0].complete(right('{"helper_volunteer":true}'));
    await pumpEventQueue();

    expect(container.read(featureFlagProvider), {'helper_volunteer': false});
  });

  test('unchanged flags keep the same map', () async {
    final service = _Service();
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(featureFlagProvider);
    service.answers[0].complete(right('{"helper_volunteer":true}'));
    await pumpEventQueue();
    final first = container.read(featureFlagProvider);

    final again = container
        .read(featureFlagProvider.notifier)
        .fetchFeatureFlags();
    service.answers[1].complete(right('{"helper_volunteer":true}'));
    await again;

    expect(identical(container.read(featureFlagProvider), first), isTrue);
  });
}
