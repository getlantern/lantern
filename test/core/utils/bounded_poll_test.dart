import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/bounded_poll.dart';

void main() {
  group('boundedPoll', () {
    test('returns the first non-null result', () async {
      final attempts = <int>[];

      final result = await boundedPoll<String>(
        timeout: const Duration(seconds: 1),
        interval: Duration.zero,
        fetch: (attempt) async {
          attempts.add(attempt);
          return attempt == 3 ? 'pro' : null;
        },
      );

      expect(result, 'pro');
      expect(attempts, [1, 2, 3]);
    });

    test('bounds a stalled fetch by the overall timeout', () async {
      final stopwatch = Stopwatch()..start();

      final result = await boundedPoll<String>(
        timeout: const Duration(milliseconds: 30),
        fetch: (_) => Future<String?>.delayed(
          const Duration(seconds: 1),
          () => 'too late',
        ),
      );

      expect(result, isNull);
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
    });
  });
}
