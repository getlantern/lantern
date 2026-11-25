import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/desktop/app_window.dart';
import 'package:nativeapi/nativeapi.dart' as nativeapi;

import '../../fakes/fake_native_window.dart';

void main() {
  late FakeNativeWindow window;
  final app = AppWindow.instance;

  nativeapi.WindowCloseRequestedEvent closeRequest(FakeCloseRequest request) =>
      nativeapi.WindowCloseRequestedEvent(windowId: 0, request: request);

  setUp(() {
    window = FakeNativeWindow()..visible = true;
    app.debugWindow = () => window;
    // Resolving the window is what attaches the event listener.
    expect(app.window, same(window));
    addTearDown(() {
      app
        ..debugWindow = null
        ..preventClose = false;
    });
  });

  test('the close button really closes until preventClose is armed', () {
    final request = FakeCloseRequest();
    window.fire(closeRequest(request));

    expect(request.cancelled, isFalse);
    expect(window.calls, isNot(contains('hide')));
  });

  test('with preventClose, the close button hides to the tray', () {
    app.preventClose = true;
    final request = FakeCloseRequest();
    window.fire(closeRequest(request));

    expect(request.cancelled, isTrue);
    expect(window.isVisible, isFalse);
  });

  test('destroy closes past preventClose', () {
    app.preventClose = true;
    app.destroy();
    final request = FakeCloseRequest();
    window.fire(closeRequest(request));

    expect(window.calls, contains('close'));
    expect(request.cancelled, isFalse);
    expect(window.calls, isNot(contains('hide')));
  });

  test('show restores a minimized window and reports the change', () {
    window
      ..visible = false
      ..minimized = true;
    var changes = 0;
    void onChange() => changes++;
    app.changed.addListener(onChange);
    addTearDown(() => app.changed.removeListener(onChange));

    expect(app.isShown, isFalse);
    expect(app.show(), isTrue);

    expect(app.isShown, isTrue);
    expect(window.calls, containsAllInOrder(['show', 'focus']));
    expect(changes, 1);
  });

  test('focus fires both signals; minimize only the change', () {
    var focused = 0, changed = 0;
    void onFocus() => focused++;
    void onChange() => changed++;
    app.focused.addListener(onFocus);
    app.changed.addListener(onChange);
    addTearDown(() {
      app.focused.removeListener(onFocus);
      app.changed.removeListener(onChange);
    });

    window.fire(const nativeapi.WindowFocusedEvent(windowId: 0));
    window.fire(const nativeapi.WindowMinimizedEvent(windowId: 0));

    expect(focused, 1);
    expect(changed, 2);
  });

  test('with no window, show reports it and isShown assumes yes', () {
    app.debugWindow = () => null;

    expect(app.show(), isFalse);
    expect(app.isShown, isTrue);
  });
}
