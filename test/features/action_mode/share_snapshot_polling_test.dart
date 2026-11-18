import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_snapshot_polling.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  final calls = <bool>[];
  bool fail = false;
  // When set, each call waits for its own completer.
  List<Completer<Either<Failure, Unit>>>? held;

  @override
  Future<Either<Failure, Unit>> setSnapshotPolling(bool on) {
    calls.add(on);
    if (held != null) {
      final c = Completer<Either<Failure, Unit>>();
      held!.add(c);
      return c.future;
    }
    return Future.value(fail ? _failure : right(unit));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _failure = left<Failure, Unit>(
  Failure(error: 'x', localizedErrorMessage: 'x'),
);

class _Share extends ShareNotifier {
  @override
  ShareState build() => const ShareState();
  void setActive(bool active) => state = state.copyWith(active: active);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Service service;
  late _Share share;
  late ProviderContainer container;

  Future<void> settle() => Future<void>.delayed(Duration.zero);
  final binding = TestWidgetsFlutterBinding.instance;

  void background() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void foreground() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    service = _Service();
    container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        shareProvider.overrideWith(() => share = _Share()),
      ],
    );
    container.read(actionModeTabVisibleProvider.notifier).set(false);
    container.read(shareSnapshotPollingProvider);
  });

  tearDown(() => container.dispose());

  test('polls fast only while the tab is visible', () async {
    await settle();
    expect(service.calls, isEmpty);

    container.read(actionModeTabVisibleProvider.notifier).set(true);
    await settle();
    expect(service.calls, [true]);

    container.read(actionModeTabVisibleProvider.notifier).set(false);
    await settle();
    expect(service.calls, [true, false]);
  });

  test('stops in the background and resumes in the foreground', () async {
    container.read(actionModeTabVisibleProvider.notifier).set(true);
    await settle();

    background();
    await settle();
    expect(service.calls, [true, false]);

    foreground();
    await settle();
    expect(service.calls, [true, false, true]);
  });

  // The backend drops a departed peer's bytes after a minute, so a pause
  // while sharing would lose them from the per-country stats.
  test('keeps fast polling while sharing, even in the background', () async {
    await settle();
    share.setActive(true);
    await settle();
    expect(service.calls, [true]);

    background();
    await settle();
    expect(service.calls, [true]);

    share.setActive(false);
    await settle();
    expect(service.calls, [true, false]);
  });

  test('a failed call is retried', () async {
    container.read(shareSnapshotPollingProvider.notifier).retryDelay =
        const Duration(milliseconds: 10);
    service.fail = true;
    container.read(actionModeTabVisibleProvider.notifier).set(true);
    await settle();
    expect(service.calls, [true]);

    service.fail = false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.calls, [true, true]);
    expect(container.read(shareSnapshotPollingProvider), isTrue);
  });

  // on, off, on are queued; the first fails after the others were asked for.
  // Its failure must not flip state, or hiding the tab would leave polling on.
  test('a superseded failure does not change state', () async {
    service.held = [];
    final tab = container.read(actionModeTabVisibleProvider.notifier);
    tab.set(true);
    await settle();
    tab.set(false);
    tab.set(true);
    await settle();
    service.held![0].complete(_failure);
    await settle();
    service.held![1].complete(right(unit));
    await settle();
    service.held![2].complete(right(unit));
    await settle();
    expect(container.read(shareSnapshotPollingProvider), isTrue);

    tab.set(false);
    await settle();
    service.held![3].complete(right(unit));
    await settle();
    expect(service.calls, [true, false, true, false]);
    expect(container.read(shareSnapshotPollingProvider), isFalse);
  });

  // on then off both fail while the core is down. The backend never left the
  // idle rate, so reopening the tab before the retry must still ask for fast.
  test('after failures, state falls back to what the backend has', () async {
    container.read(shareSnapshotPollingProvider.notifier).retryDelay =
        const Duration(hours: 1);
    service.fail = true;
    final tab = container.read(actionModeTabVisibleProvider.notifier);
    tab.set(true);
    tab.set(false);
    await settle();
    await settle();
    expect(service.calls, [true, false]);
    expect(container.read(shareSnapshotPollingProvider), isFalse);

    service.fail = false;
    tab.set(true);
    await settle();
    expect(service.calls, [true, false, true]);
    expect(container.read(shareSnapshotPollingProvider), isTrue);
  });
}
