import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/features/vpn/latency_indicator.dart';

void main() {
  group('LatencyStatus.of', () {
    test('shows the last successful probe', () {
      final status = LatencyStatus.of(_server(delay: 120));
      expect(status, isA<LatencyMeasured>());
      expect((status as LatencyMeasured).ms, 120);
    });

    test('is testing until the first verdict', () {
      expect(LatencyStatus.of(_server()), isA<LatencyTesting>());
    });

    test('keeps the latency through a transient failure', () {
      final status = LatencyStatus.of(_server(delay: 120, failures: 2));
      expect((status as LatencyMeasured).ms, 120);
    });

    test('a failure without a success yet is not unreachable', () {
      expect(
        LatencyStatus.of(_server(delay: 0, failures: 1)),
        isA<LatencyTesting>(),
      );
    });

    test('sustained failures read as unreachable, even after a success', () {
      expect(
        LatencyStatus.of(_server(delay: 120, failures: 3)),
        isA<LatencyUnreachable>(),
      );
    });
  });

  test('isFast threshold', () {
    expect(const LatencyMeasured(fastLatencyThresholdMs - 1).isFast, isTrue);
    expect(const LatencyMeasured(fastLatencyThresholdMs).isFast, isFalse);
  });

  group('LatencyStatus.best', () {
    test('picks the fastest measured server', () {
      final status = LatencyStatus.best([
        _server(delay: 220),
        _server(),
        _server(delay: 10, failures: 3),
        _server(delay: 95),
      ]);
      expect((status as LatencyMeasured).ms, 95);
    });

    test('testing beats unreachable', () {
      expect(
        LatencyStatus.best([_server(delay: 10, failures: 3), _server()]),
        isA<LatencyTesting>(),
      );
    });

    test('all unreachable reads as unreachable', () {
      expect(
        LatencyStatus.best([_server(failures: 3), _server(failures: 4)]),
        isA<LatencyUnreachable>(),
      );
    });
  });

  testWidgets('LatencyIndicator labels', (tester) async {
    Future<void> pump(LatencyStatus status) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LatencyIndicator(status: status)),
      ),
    );

    await pump(const LatencyMeasured(42));
    expect(find.text('42 ms'), findsOneWidget);

    await pump(const LatencyTesting());
    expect(find.text('latency_testing'), findsOneWidget);

    await pump(const LatencyUnreachable());
    expect(find.text('latency_unreachable'), findsOneWidget);
  });
}

Server _server({int? delay, int failures = 0}) {
  final hasHistory = delay != null || failures > 0;
  return Server(
    tag: 'tag',
    type: 'samizdat',
    isLantern: true,
    location: GeoLocation(
      country: 'United States',
      countryCode: 'US',
      city: 'New York',
      latitude: 0,
      longitude: 0,
    ),
    selectionHistory: !hasHistory
        ? null
        : SelectionHistory(
            lastSuccessDelayMs: delay ?? 0,
            consecutiveFailures: failures,
          ),
  );
}
