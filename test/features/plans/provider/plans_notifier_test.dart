import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

PlansData _plans() => PlansData(
  providers: Providers(android: [], desktop: []),
  plans: [],
);

class _FakeStorage extends LocalStorageService {
  _FakeStorage(this.cached);

  final PlansData? cached;
  final saved = <PlansData>[];

  @override
  PlansData? getPlans() => cached;

  @override
  Future<void> savePlans(PlansData plans) async => saved.add(plans);
}

class _FakeLanternService implements LanternService {
  final fetches = <Completer<Either<Failure, PlansData>>>[];

  @override
  Future<Either<Failure, PlansData>> plans() {
    final fetch = Completer<Either<Failure, PlansData>>();
    fetches.add(fetch);
    return fetch.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeLanternService service;
  late ProviderContainer container;

  Future<void> start(PlansData? cached) async {
    sl.registerSingleton<LocalStorageService>(_FakeStorage(cached));
    addTearDown(() => sl.unregister<LocalStorageService>());
    service = _FakeLanternService();
    container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
  }

  /// Watches the provider until its plans fetch starts, then stops watching so
  /// it is disposed with the fetch still in flight.
  Future<void> disposeDuringFetch() async {
    final watch = container.listen(plansProvider, (_, _) {});
    await pumpEventQueue();
    expect(service.fetches, hasLength(1));
    watch.close();
    await container.pump();
  }

  Either<Failure, PlansData> failure() =>
      left(Failure(error: 'offline', localizedErrorMessage: 'Offline'));

  test('a background refresh that fails after disposal is ignored', () async {
    await start(_plans());
    await disposeDuringFetch();

    service.fetches.single.complete(failure());
    await pumpEventQueue();
  });

  test('a background refresh that finishes after disposal is cached', () async {
    await start(_plans());
    await disposeDuringFetch();

    final remote = _plans();
    service.fetches.single.complete(right(remote));
    await pumpEventQueue();

    expect((sl<LocalStorageService>() as _FakeStorage).saved, [remote]);
  });

  // testWidgets runs in fake time and fails if a timer is left pending, which
  // is what a retry scheduled on the disposed provider would leave.
  testWidgets('a first fetch that fails after disposal does not retry', (
    tester,
  ) async {
    await start(null);
    final watch = container.listen(plansProvider, (_, _) {});
    await tester.pump();
    expect(service.fetches, hasLength(1));
    watch.close();
    // Riverpod disposes on a zero-duration timer.
    await tester.pump(const Duration(milliseconds: 1));

    service.fetches.single.complete(failure());
    await tester.pump();
    expect(service.fetches, hasLength(1));
  });
}
