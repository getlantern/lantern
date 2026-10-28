import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

const _initial = SplitTunnelState(
  enabled: true,
  policy: SplitTunnelPolicy.bypass,
  supported: true,
);
final _failure = Failure(
  error: 'apply failed',
  localizedErrorMessage: 'Apply failed',
);

class _Service implements LanternService {
  SplitTunnelState snapshot = _initial;
  final calls = <String>[];
  Future<Either<Failure, SplitTunnelState>> Function()? read;
  Failure? mutationFailure;

  @override
  Future<Either<Failure, SplitTunnelState>> getSplitTunnelState() async {
    calls.add('read');
    return read == null ? right(snapshot) : read!();
  }

  @override
  Future<Either<Failure, Unit>> setSplitTunnelingEnabled(bool enabled) async {
    calls.add('enabled:$enabled');
    snapshot = SplitTunnelState(
      enabled: enabled,
      policy: snapshot.policy,
      supported: snapshot.supported,
      filters: snapshot.filters,
    );
    return mutationFailure == null ? right(unit) : left(mutationFailure!);
  }

  @override
  Future<Either<Failure, SplitTunnelState>> switchSplitTunnelPolicy(
    String policy,
  ) async {
    calls.add('switch:$policy');
    if (mutationFailure != null) return left(mutationFailure!);
    snapshot = SplitTunnelState(
      enabled: snapshot.enabled,
      policy: policy == 'include'
          ? SplitTunnelPolicy.includeOnly
          : SplitTunnelPolicy.bypass,
      supported: true,
    );
    return right(snapshot);
  }

  @override
  Future<Either<Failure, SplitTunnelState>> clearSplitTunnelApps() async {
    calls.add('clear');
    snapshot = SplitTunnelState(
      enabled: snapshot.enabled,
      policy: snapshot.policy,
      supported: snapshot.supported,
      filters: {
        for (final entry in snapshot.filters.entries)
          if (!SplitTunnelState.appTypes.contains(entry.key))
            entry.key: entry.value,
      },
    );
    return right(snapshot);
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) async {
    calls.add('add:$value');
    snapshot = SplitTunnelState(
      enabled: snapshot.enabled,
      policy: snapshot.policy,
      supported: snapshot.supported,
      filters: {
        ...snapshot.filters,
        type: [...snapshot.selectors(type), value],
      },
    );
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) async {
    calls.add('remove:$value');
    snapshot = SplitTunnelState(
      enabled: snapshot.enabled,
      policy: snapshot.policy,
      supported: snapshot.supported,
      filters: {
        ...snapshot.filters,
        type: snapshot.selectors(type).where((s) => s != value).toList(),
      },
    );
    return right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Service service;
  late ProviderContainer container;
  setUp(() {
    service = _Service();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
  });
  tearDown(() => container.dispose());

  test('failed reads are errors and can be retried', () async {
    service.read = () async => left(_failure);
    await expectLater(
      container.read(splitTunnelProvider.future),
      throwsA(same(_failure)),
    );
    expect(container.read(splitTunnelProvider).hasError, isTrue);
    service.read = null;
    expect(
      await container.read(splitTunnelProvider.notifier).refresh(),
      isNull,
    );
    expect(container.read(splitTunnelProvider).requireValue.enabled, isTrue);
  });

  test('rapid toggles use the latest committed selectors', () async {
    await container.read(splitTunnelProvider.future);
    final notifier = container.read(splitTunnelProvider.notifier);
    final first = notifier.setSelector(
      SplitTunnelFilterType.packageName,
      'example.app',
    );
    final second = notifier.setSelector(
      SplitTunnelFilterType.packageName,
      'example.app',
    );
    expect(await first, isNull);
    expect(await second, isNull);
    expect(service.calls, [
      'read',
      'add:example.app',
      'read',
      'remove:example.app',
      'read',
    ]);
    expect(container.read(splitTunnelProvider).requireValue.appCount, 0);
  });

  test('delayed refresh cannot restore state after queued mutation', () async {
    await container.read(splitTunnelProvider.future);
    final delayed = Completer<Either<Failure, SplitTunnelState>>();
    service.read = () => delayed.future;
    final notifier = container.read(splitTunnelProvider.notifier);
    final refresh = notifier.refresh();
    await Future<void>.delayed(Duration.zero);
    final mutation = notifier.setEnabled(false);
    expect(service.calls, ['read', 'read']);
    service.read = null;
    delayed.complete(right(_initial));
    await refresh;
    await mutation;
    expect(container.read(splitTunnelProvider).requireValue.enabled, isFalse);
  });

  test(
    'invalidation discards an old refresh and reads the new snapshot',
    () async {
      await container.read(splitTunnelProvider.future);
      final delayed = Completer<Either<Failure, SplitTunnelState>>();
      service.read = () => delayed.future;
      final notifier = container.read(splitTunnelProvider.notifier);
      final refresh = notifier.refresh();
      await Future<void>.delayed(Duration.zero);
      container.invalidate(splitTunnelProvider);
      final rebuilt = container.read(splitTunnelProvider.future);
      service.snapshot = const SplitTunnelState(
        enabled: false,
        policy: SplitTunnelPolicy.includeOnly,
        supported: true,
      );
      service.read = null;
      delayed.complete(right(_initial));
      await refresh;
      expect((await rebuilt).policy, SplitTunnelPolicy.includeOnly);
      expect(container.read(splitTunnelProvider).requireValue.enabled, isFalse);
    },
  );

  test(
    'apply failure remains explicit while persisted state is refreshed',
    () async {
      await container.read(splitTunnelProvider.future);
      service.mutationFailure = _failure;
      expect(
        await container.read(splitTunnelProvider.notifier).setEnabled(false),
        same(_failure),
      );
      expect(container.read(splitTunnelProvider).requireValue.enabled, isFalse);
    },
  );

  test(
    'same-mode retry keeps selections and old daemons cannot switch',
    () async {
      service.snapshot = const SplitTunnelState(
        enabled: true,
        policy: SplitTunnelPolicy.bypass,
        supported: false,
        filters: {
          SplitTunnelFilterType.packageName: ['missing.app'],
        },
      );
      await container.read(splitTunnelProvider.future);
      final notifier = container.read(splitTunnelProvider.notifier);
      expect(await notifier.switchPolicy(SplitTunnelPolicy.bypass), isNull);
      expect(
        await notifier.switchPolicy(SplitTunnelPolicy.includeOnly),
        isA<Failure>(),
      );
      expect(service.calls, ['read']);
      expect(container.read(splitTunnelProvider).requireValue.appCount, 1);
    },
  );

  test('switch failure keeps truthful state and reports error', () async {
    await container.read(splitTunnelProvider.future);
    service.mutationFailure = _failure;
    expect(
      await container
          .read(splitTunnelProvider.notifier)
          .switchPolicy(SplitTunnelPolicy.includeOnly),
      same(_failure),
    );
    expect(
      container.read(splitTunnelProvider).requireValue.policy,
      SplitTunnelPolicy.bypass,
    );
  });

  test('clear removes every app category and preserves websites', () async {
    service.snapshot = const SplitTunnelState(
      enabled: true,
      policy: SplitTunnelPolicy.includeOnly,
      supported: true,
      filters: {
        SplitTunnelFilterType.processName: ['hidden.exe'],
        SplitTunnelFilterType.processPath: [r'C:\Removed\removed.exe'],
        SplitTunnelFilterType.processPathRegex: ['hidden/.*'],
        SplitTunnelFilterType.packageName: ['missing.package'],
        SplitTunnelFilterType.domainSuffix: ['example.com'],
      },
    );
    await container.read(splitTunnelProvider.future);
    expect(
      await container.read(splitTunnelProvider.notifier).clearApps(),
      isNull,
    );
    final state = container.read(splitTunnelProvider).requireValue;
    expect(state.appCount, 0);
    expect(state.selectors(SplitTunnelFilterType.domainSuffix), [
      'example.com',
    ]);
  });
}
