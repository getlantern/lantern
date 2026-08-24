import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/first_frame_watchdog.dart';

/// Covers the recovery path for getlantern/engineering#3833: the app builds
/// frames but the rasterizer never puts one on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method.startsWith('is')) return false;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    FirstFrameWatchdog.resetForTest();
    addTearDown(FirstFrameWatchdog.resetForTest);
  });

  List<String> methods() => calls.map((c) => c.method).toList();

  testWidgets('reveals a closable window when no frame is ever presented', (
    tester,
  ) async {
    if (!PlatformUtils.isDesktop) return;

    FirstFrameWatchdog.start();
    // A frame is built here. The test binding never rasterizes one, which is
    // exactly the state being guarded against.
    await tester.pump();
    expect(
      methods(),
      isEmpty,
      reason: 'the watchdog must not act before its timeout',
    );

    await tester.pump(const Duration(seconds: 11));

    expect(
      methods(),
      containsAllInOrder(<String>['setPreventClose', 'show']),
      reason: 'a blank window must be revealed, and revealed closable',
    );
    final preventClose = calls.firstWhere((c) => c.method == 'setPreventClose');
    expect(
      preventClose.arguments['isPreventClose'],
      isFalse,
      reason:
          'close interception must be off, or the blank window traps the '
          'user exactly as in #3833',
    );
    expect(FirstFrameWatchdog.recoveredFromTimeout, isTrue);
  });

  testWidgets('start() is idempotent', (tester) async {
    if (!PlatformUtils.isDesktop) return;

    FirstFrameWatchdog.start();
    FirstFrameWatchdog.start();
    FirstFrameWatchdog.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));

    // A second timer would reveal the window again after the first recovery.
    expect(
      methods().where((m) => m == 'show').length,
      1,
      reason: 'repeated start() calls must not stack timers',
    );
  });
}
