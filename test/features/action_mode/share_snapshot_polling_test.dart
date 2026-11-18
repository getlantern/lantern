import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_snapshot_polling.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  final calls = <bool>[];
  bool fail = false;
  @override
  Future<Either<Failure, Unit>> setSnapshotPolling(bool on) async {
    calls.add(on);
    return fail
        ? left(Failure(error: 'x', localizedErrorMessage: 'x'))
        : right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Share extends ShareNotifier {
  int paused = 0;
  @override
  ShareState build() => const ShareState();
  @override
  void snapshotsPaused() => paused++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Service service;
  late _Share share;
  late ProviderContainer container;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    PlatformUtils.debugIsDesktop = false;
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

  tearDown(() {
    container.dispose();
    PlatformUtils.debugIsDesktop = null;
  });

  test('polls only while the tab is visible', () async {
    await settle();
    expect(service.calls, isEmpty);

    container.read(actionModeTabVisibleProvider.notifier).set(true);
    await settle();
    expect(service.calls, [true]);

    container.read(actionModeTabVisibleProvider.notifier).set(false);
    await settle();
    expect(service.calls, [true, false]);
    expect(share.paused, 1);
  });

  test('stops in the background and resumes in the foreground', () async {
    container.read(actionModeTabVisibleProvider.notifier).set(true);
    await settle();

    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle();
    expect(service.calls, [true, false]);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle();
    expect(service.calls, [true, false, true]);
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
}
