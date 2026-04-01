import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/latest_async_queue.dart';

void main() {
  test(
    'coalesces queued values and applies only latest pending value',
    () async {
      final startedFirstApply = Completer<void>();
      final allowFirstApplyToFinish = Completer<void>();
      final applied = <int>[];

      final queue = LatestAsyncQueue<int, int>(
        defaultResult: -1,
        worker: (value) async {
          applied.add(value);
          if (value == 1) {
            startedFirstApply.complete();
            await allowFirstApplyToFinish.future;
          }
          return value;
        },
      );

      final first = queue.enqueue(1);
      await startedFirstApply.future;
      final second = queue.enqueue(2);
      final third = queue.enqueue(3);

      allowFirstApplyToFinish.complete();

      expect(await first, 3);
      expect(await second, 3);
      expect(await third, 3);
      expect(applied, [1, 3]);
    },
  );

  test('starts a new cycle after queue drains', () async {
    final applied = <int>[];
    final queue = LatestAsyncQueue<int, int>(
      defaultResult: -1,
      worker: (value) async {
        applied.add(value);
        return value;
      },
    );

    final firstCycle = await queue.enqueue(10);
    final secondCycle = await queue.enqueue(20);

    expect(firstCycle, 10);
    expect(secondCycle, 20);
    expect(applied, [10, 20]);
    expect(queue.isRunning, isFalse);
  });
}
