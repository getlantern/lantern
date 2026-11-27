import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/app_window.dart';
import 'package:lantern/core/desktop/desktop_window.dart';

import '../../fakes/fake_native_window.dart';

/// Guards the ordering fix for getlantern/engineering#3833.
///
/// `configureDesktopWindow` runs from `main()`, before `runApp`. Anything it
/// does happens while there is no widget tree: no rendered frame, and no
/// focus listener registered. Two calls therefore must not move back into it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  setUp(() {
    final window = FakeNativeWindow();
    calls = window.calls;
    AppWindow.instance
      ..debugWindow = (() => window)
      // A known display, so the size does not depend on the runner's screen.
      ..debugWorkArea = () => const Size(1920, 1040);
    addTearDown(() {
      AppWindow.instance
        ..debugWindow = null
        ..debugWorkArea = null
        ..preventClose = false;
    });
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
    // to AppWindow. Nothing can bring the window back until WindowWrapper's
    // initState, so arming it here leaves the window impossible to close.
    expect(
      AppWindow.instance.preventClose,
      isFalse,
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
    expect(calls, containsAll(['setSize', 'setMinimumSize', 'setMaximumSize']));
  });
}
