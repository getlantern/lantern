import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';

void main() {
  group('shouldRetryWindowsStatusStream', () {
    test('stops retrying once attempts reach the cap', () {
      expect(
        shouldRetryWindowsStatusStream(
          serviceState: WindowsServiceState.running,
          attempts: 5,
          maxAttempts: 6,
        ),
        isTrue,
      );
      expect(
        shouldRetryWindowsStatusStream(
          serviceState: WindowsServiceState.running,
          attempts: 6,
          maxAttempts: 6,
        ),
        isFalse,
      );
    });

    test('does not retry when the service is gone', () {
      expect(
        shouldRetryWindowsStatusStream(
          serviceState: WindowsServiceState.missing,
          attempts: 0,
          maxAttempts: 6,
        ),
        isFalse,
      );
      expect(
        shouldRetryWindowsStatusStream(
          serviceState: WindowsServiceState.stopped,
          attempts: 0,
          maxAttempts: 6,
        ),
        isFalse,
      );
    });
  });

  group('nextWindowsStatusReattachDelay', () {
    test('backs off and caps at the configured maximum', () {
      const initial = Duration(seconds: 1);
      const max = Duration(seconds: 30);

      expect(
        nextWindowsStatusReattachDelay(
          attempt: 0,
          initialDelay: initial,
          maxDelay: max,
        ),
        initial,
      );
      expect(
        nextWindowsStatusReattachDelay(
          attempt: 1,
          initialDelay: initial,
          maxDelay: max,
        ),
        const Duration(seconds: 2),
      );
      expect(
        nextWindowsStatusReattachDelay(
          attempt: 4,
          initialDelay: initial,
          maxDelay: max,
        ),
        const Duration(seconds: 16),
      );
      expect(
        nextWindowsStatusReattachDelay(
          attempt: 6,
          initialDelay: initial,
          maxDelay: max,
        ),
        max,
      );
    });
  });

  group('shouldApplyWindowsStatusSnapshot', () {
    test('does not override active transitions', () {
      expect(
        shouldApplyWindowsStatusSnapshot(
          current: LanternStatus.fromJson({
            'status': 'connecting',
            'origin': VPNStatusOrigin.userAction.wireValue,
          }),
          nextStatus: LanternStatus.fromJson({'status': 'disconnected'}).status,
          origin: VPNStatusOrigin.system,
        ),
        isFalse,
      );
      expect(
        shouldApplyWindowsStatusSnapshot(
          current: LanternStatus.fromJson({
            'status': 'disconnecting',
            'origin': VPNStatusOrigin.userAction.wireValue,
          }),
          nextStatus: LanternStatus.fromJson({'status': 'connected'}).status,
          origin: VPNStatusOrigin.system,
        ),
        isFalse,
      );
    });

    test('skips no-op snapshots but still clears stale errors', () {
      expect(
        shouldApplyWindowsStatusSnapshot(
          current: LanternStatus.fromJson({
            'status': 'connected',
            'origin': VPNStatusOrigin.system.wireValue,
          }),
          nextStatus: LanternStatus.fromJson({'status': 'connected'}).status,
          origin: VPNStatusOrigin.system,
        ),
        isFalse,
      );

      expect(
        shouldApplyWindowsStatusSnapshot(
          current: LanternStatus(
            status: LanternStatus.fromJson({'status': 'connected'}).status,
            origin: VPNStatusOrigin.system,
            error: 'stale',
          ),
          nextStatus: LanternStatus.fromJson({'status': 'connected'}).status,
          origin: VPNStatusOrigin.system,
        ),
        isTrue,
      );
    });
  });

  group('nextWindowsStatusRefreshStatus', () {
    test('only confirms the transition that is already in flight', () {
      expect(
        nextWindowsStatusRefreshStatus(
          pendingStatus: LanternStatus.fromJson({
            'status': 'connecting',
          }).status,
          running: false,
        ),
        isNull,
      );
      expect(
        nextWindowsStatusRefreshStatus(
          pendingStatus: LanternStatus.fromJson({
            'status': 'connecting',
          }).status,
          running: true,
        ),
        LanternStatus.fromJson({'status': 'connected'}).status,
      );
      expect(
        nextWindowsStatusRefreshStatus(
          pendingStatus: LanternStatus.fromJson({
            'status': 'disconnecting',
          }).status,
          running: true,
        ),
        isNull,
      );
      expect(
        nextWindowsStatusRefreshStatus(
          pendingStatus: LanternStatus.fromJson({
            'status': 'disconnecting',
          }).status,
          running: false,
        ),
        LanternStatus.fromJson({'status': 'disconnected'}).status,
      );
    });
  });
}
