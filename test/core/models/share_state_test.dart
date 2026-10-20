import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/share_state.dart';

void main() {
  group('ShareState.fallbackReason', () {
    const fallback = ShareState(
      active: true,
      mode: ShareMode.unbounded,
      fallbackReason: "router isn't forwarding",
    );

    test('is kept while the fallback session keeps sharing', () {
      expect(
        fallback.copyWith(unboundedRunning: true).fallbackReason,
        "router isn't forwarding",
      );
    });

    // A snapshot that stops sharing must not leave the reason for a later
    // session, which would then show a failure that is no longer current.
    test('is dropped once sharing stops', () {
      final off = fallback.copyWith(active: false, mode: ShareMode.off);
      expect(off.fallbackReason, isNull);
      expect(
        off.copyWith(active: true, mode: ShareMode.unbounded).fallbackReason,
        isNull,
      );
    });
  });
}
