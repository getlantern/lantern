import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/window/window_wrapper.dart';

/// Covers the reveal half of getlantern/engineering#3833.
///
/// The test binding builds frames but never rasterizes one, which is the exact
/// state the fix is about: Dart healthy, nothing on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');

  late List<String> calls;

  setUp(() {
    calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method.startsWith('is')) return false;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
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
      calls,
      isNot(contains('setPreventClose')),
      reason:
          'close interception must not be armed over a window that has '
          'never rendered, or the close button stops working',
    );
  });
}
