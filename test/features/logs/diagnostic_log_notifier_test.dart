import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/logs/provider/diagnostic_log_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/lantern/log_batch_stream.dart';

class _FakeLanternService implements LanternService {
  _FakeLanternService(this.logs);

  final Stream<List<String>> logs;

  @override
  Stream<List<String>> watchLogs(String path) => logs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late StreamController<String> port;
  late List<bool> calls;
  late ProviderContainer container;

  setUp(() {
    port = StreamController<String>();
    calls = [];
    final logs = LogBatchStream(
      port.stream,
      (active) async => calls.add(active),
    );
    container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(
          _FakeLanternService(logs.stream),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    return port.close();
  });

  test('drops lines while another screen covers the Logs screen', () async {
    final sub = container.listen(diagnosticLogProvider, (_, _) {});
    await pumpEventQueue();
    port.add('before');
    await pumpEventQueue();

    sub.pause();
    await pumpEventQueue();
    for (var i = 0; i < 100; i++) {
      port.add('covered $i');
    }
    await pumpEventQueue();
    sub.resume();
    await pumpEventQueue();
    port.add('after');
    await pumpEventQueue();

    expect(container.read(diagnosticLogProvider).value, ['before', 'after']);
    sub.close();
  });

  test('turns Go off as soon as the Logs screen closes', () async {
    final sub = container.listen(diagnosticLogProvider, (_, _) {});
    await pumpEventQueue();
    expect(calls, [true]);

    sub.close();
    await pumpEventQueue();

    expect(calls, [true, false]);
  });
}
