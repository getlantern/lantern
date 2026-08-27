import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/desktop_window.dart';

/// Guards the ordering fix for getlantern/engineering#3833.
///
/// `configureDesktopWindow` runs from `main()`, before `runApp`. Anything it
/// does happens while there is no widget tree: no rendered frame, and no
/// `WindowListener` registered. Two calls therefore must not move back into it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  const screenChannel = MethodChannel(
    'dev.leanflutter.plugins/screen_retriever',
  );

  late List<String> calls;

  setUp(() {
    calls = <String>[];

    // Pinned to a known display so the computed window size is deterministic
    // and does not depend on the CI runner's screen. Both display methods are
    // answered: screen_retriever resolves the primary display through
    // getAllDisplays, and an unanswered call there escapes the caller's
    // try/catch as a NoSuchMethodError rather than a MissingPluginException.
    const display = <String, dynamic>{
      'id': 'test-display',
      'name': 'test-display',
      'size': <String, dynamic>{'width': 1920.0, 'height': 1080.0},
      'visibleSize': <String, dynamic>{'width': 1920.0, 'height': 1040.0},
      'visiblePosition': <String, dynamic>{'dx': 0.0, 'dy': 0.0},
      'scaleFactor': 1.0,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenChannel, (call) async {
          switch (call.method) {
            case 'getPrimaryDisplay':
              return display;
            case 'getCursorScreenPoint':
              return <String, dynamic>{'dx': 0.0, 'dy': 0.0};
            case 'getAllDisplays':
              return <String, dynamic>{
                'displays': <Map<String, dynamic>>[display],
              };
            default:
              return null;
          }
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(screenChannel, null),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          // window_manager's setters query state internally (setResizable reads
          // isFullScreen), and those getters are typed, so a blanket null reply
          // fails before the call under test is ever reached.
          if (call.method.startsWith('is')) return false;
          if (call.method == 'getBounds') {
            return <String, double>{
              'x': 0.0,
              'y': 0.0,
              'width': 390.0,
              'height': 800.0,
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  });

  test('does not show the window before a frame exists', () async {
    if (!PlatformUtils.isDesktop) return;

    await configureDesktopWindow();
    // Drain pending work: the pre-fix code revealed the window from an
    // un-awaited waitUntilReadyToShow callback, so without this the call
    // lands after the assertion and the regression slips through.
    await pumpEventQueue();

    // Showing here would put a window on screen that has never rendered, so a
    // failure to rasterize reaches the user as a blank window rather than as an
    // app that has not opened yet.
    expect(
      calls,
      isNot(contains('show')),
      reason:
          'the window must be revealed after the first frame, not from '
          'main() — see WindowWrapper._revealWindow',
    );
  });

  test('does not arm preventClose before a close listener exists', () async {
    if (!PlatformUtils.isDesktop) return;

    await configureDesktopWindow();
    // Drain pending work: the pre-fix code revealed the window from an
    // un-awaited waitUntilReadyToShow callback, so without this the call
    // lands after the assertion and the regression slips through.
    await pumpEventQueue();

    // preventClose suppresses the native destroy and hands the close request to
    // a Dart WindowListener. No listener is registered until WindowWrapper's
    // initState, so arming it here leaves the window impossible to close.
    expect(
      calls,
      isNot(contains('setPreventClose')),
      reason:
          'preventClose must be armed alongside the listener in '
          'WindowWrapper, never from main()',
    );
  });

  test('still applies the window options', () async {
    if (!PlatformUtils.isDesktop) return;

    await configureDesktopWindow();
    // Drain pending work: the pre-fix code revealed the window from an
    // un-awaited waitUntilReadyToShow callback, so without this the call
    // lands after the assertion and the regression slips through.
    await pumpEventQueue();

    // The sizing work still has to happen here; only the reveal is deferred.
    expect(calls, contains('waitUntilReadyToShow'));
  });
}
