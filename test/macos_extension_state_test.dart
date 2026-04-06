import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/macos_extension_state.dart';

void main() {
  group('MacOSExtensionState', () {
    test('parses typed map payloads from event channel', () {
      final payload = <String, dynamic>{
        'status': 'updatePending',
        'details': 'typed map payload',
      };

      final state = MacOSExtensionState.fromEvent(payload);

      expect(state.status, SystemExtensionStatus.updatePending);
      expect(state.message, 'typed map payload');
    });

    test('parses structured status events', () {
      final state = MacOSExtensionState.fromEvent(const {
        'status': 'updatePending',
        'details': 'active system extension is newer than the current app',
      });

      expect(state.status, SystemExtensionStatus.updatePending);
      expect(
        state.message,
        'active system extension is newer than the current app',
      );
      expect(state.isReady, isFalse);
    });

    test('parses requiresReboot from structured and legacy payloads', () {
      final structured = MacOSExtensionState.fromEvent(const {
        'status': 'requiresReboot',
        'details': 'system extension changes are waiting on a reboot',
      });
      final legacy = MacOSExtensionState.fromString(
        'requiresReboot:system extension changes are waiting on a reboot',
      );

      expect(structured.status, SystemExtensionStatus.requiresReboot);
      expect(
        structured.message,
        'system extension changes are waiting on a reboot',
      );
      expect(legacy.status, SystemExtensionStatus.requiresReboot);
      expect(
        legacy.message,
        'system extension changes are waiting on a reboot',
      );
    });

    test('treats activated as ready', () {
      final state = MacOSExtensionState.fromEvent(const {
        'status': 'activated',
      });

      expect(state.status, SystemExtensionStatus.activated);
      expect(state.isReady, isTrue);
    });
  });
}
