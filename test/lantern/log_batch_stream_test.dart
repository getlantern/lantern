import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/lantern/log_batch_stream.dart';

void main() {
  late StreamController<String> port;
  late List<bool> calls;

  setUp(() {
    port = StreamController<String>();
    calls = [];
  });

  tearDown(() => port.close());

  LogBatchStream logsWith([Future<void> Function(bool active)? setActive]) =>
      LogBatchStream(
        port.stream,
        setActive ?? (active) async => calls.add(active),
      );

  test('drops lines while nothing listens', () async {
    final logs = logsWith();
    port.add('before');
    await pumpEventQueue();

    final got = <List<String>>[];
    final sub = logs.stream.listen(got.add);
    port.add('after');
    await pumpEventQueue();

    expect(got, [
      ['after'],
    ]);
    await sub.cancel();
  });

  test('splits each message into non-empty lines', () async {
    final logs = logsWith();
    final got = <List<String>>[];
    final sub = logs.stream.listen(got.add);
    port.add('one\r\ntwo\n\nthree\n');
    port.add('\n');
    await pumpEventQueue();

    expect(got, [
      ['one', 'two', 'three'],
    ]);
    await sub.cancel();
  });

  test('turns Go on for the first listener and off after the last', () async {
    final logs = logsWith();
    final a = logs.stream.listen((_) {});
    final b = logs.stream.listen((_) {});
    await a.cancel();
    await pumpEventQueue();
    expect(calls, [true]);

    await b.cancel();
    await pumpEventQueue();
    expect(calls, [true, false]);
  });

  test('can be listened to again after the last listener leaves', () async {
    final logs = logsWith();
    await logs.stream.listen((_) {}).cancel();

    final got = <List<String>>[];
    final sub = logs.stream.listen(got.add);
    port.add('again');
    await pumpEventQueue();

    expect(got, [
      ['again'],
    ]);
    expect(calls, [true, false, true]);
    await sub.cancel();
  });

  test('applies updates in order when one is slow', () async {
    final slow = Completer<void>();
    final logs = logsWith((active) async {
      if (calls.isEmpty) await slow.future;
      calls.add(active);
    });

    await logs.stream.listen((_) {}).cancel();
    final sub = logs.stream.listen((_) {});
    await pumpEventQueue();
    expect(calls, isEmpty);

    slow.complete();
    await pumpEventQueue();
    expect(calls, [true, false, true]);
    await sub.cancel();
  });

  test('keeps going after an update fails', () async {
    final logs = logsWith((active) async {
      calls.add(active);
      if (calls.length == 1) throw StateError('not_initialized');
    });

    await logs.stream.listen((_) {}).cancel();
    await pumpEventQueue();

    expect(calls, [true, false]);
  });
}
