import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  Completer<Either<Failure, AvailableServers>>? pendingFetch;
  final pendingFetchStarted = Completer<void>();
  int fetchCalls = 0;

  @override
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers() {
    fetchCalls += 1;
    final pending = pendingFetch;
    if (pending != null) {
      if (!pendingFetchStarted.isCompleted) {
        pendingFetchStarted.complete();
      }
      return pending.future;
    }
    return Future.value(right(AvailableServers([])));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'probe-settle refresh stops when disposed during the first fetch',
    () async {
      final service = _FakeLanternService();
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );

      await container.read(availableServersProvider.future);
      final notifier = container.read(availableServersProvider.notifier);
      final pending = Completer<Either<Failure, AvailableServers>>();
      service.pendingFetch = pending;

      final refresh = notifier.refreshAvailableServersAfterProbeSettle();
      await service.pendingFetchStarted.future;
      container.dispose();
      pending.complete(right(AvailableServers([])));

      await expectLater(refresh.timeout(const Duration(seconds: 2)), completes);
      expect(service.fetchCalls, 2);
    },
  );
}
