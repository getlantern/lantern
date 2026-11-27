import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/app_window.dart';
import 'package:lantern/features/window/window_wrapper.dart';

import '../../fakes/fake_native_window.dart';

/// Covers the reveal half of getlantern/engineering#3833.
///
/// The test binding builds frames but never rasterizes one, which is the exact
/// state the fix is about: Dart healthy, nothing on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  setUp(() {
    final window = FakeNativeWindow();
    calls = window.calls;
    AppWindow.instance.debugWindow = () => window;
    addTearDown(() {
      AppWindow.instance
        ..debugWindow = null
        ..preventClose = false;
    });
  });

  testWidgets('does not reveal the window until a frame is presented', (
    tester,
  ) async {
    if (!PlatformUtils.isDesktop) return;

    await tester.pumpWidget(
      const ProviderScope(child: WindowWrapper(child: SizedBox())),
    );
    // Several frames are built here; none is rasterized.
    await tester.pump(const Duration(seconds: 1));

    expect(
      calls,
      isNot(contains('show')),
      reason:
          'a built frame is not a presented one — revealing on '
          'addPostFrameCallback exposes the blank window from #3833',
    );
    expect(
      AppWindow.instance.preventClose,
      isFalse,
      reason:
          'close interception must not be armed over a window that has '
          'never rendered, or the close button stops working',
    );
  });
}
