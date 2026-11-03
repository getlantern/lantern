import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/main.dart' as app;

import 'app_robot.dart';

/// Registers a test that launches to home and logs network diagnostics.
void registerNetworkDiagnostics(String label) {
  testWidgets('network diagnostics: $label', (tester) async {
    await app.main();
    final robot = AppRobot(tester);
    await robot.launchToHome();
    await logNetworkDiagnostics(
      label,
      container: ProviderScope.containerOf(
        robot.homeScreen.evaluate().first,
        listen: false,
      ),
    );
  });
}

/// Logs one `NETDIAG [label]` line per check, comparing what the network allows
/// directly (system DNS, plain TLS, raw TCP) with what the app's own backend
/// client manages. Never fails: it only records.
Future<void> logNetworkDiagnostics(
  String label, {
  ProviderContainer? container,
}) async {
  final checks = <String, Future<String> Function()>{
    'dns api.getiantem.org': () => _lookup('api.getiantem.org'),
    'dns df.iantem.io': () => _lookup('df.iantem.io'),
    'https api.getiantem.org': () => _get('https://api.getiantem.org/'),
    'https df.iantem.io': () => _get('https://df.iantem.io/'),
    // DNS-over-HTTPS resolvers the smart dialer tries.
    'tcp 208.67.222.222:443': () => _connect('208.67.222.222', 443),
    'tcp 1.1.1.1:443': () => _connect('1.1.1.1', 443),
    'tcp 8.8.8.8:443': () => _connect('8.8.8.8', 443),
    // Domain fronts seen timing out in Test Lab.
    'tcp a248.e.akamai.net:443': () => _connect('a248.e.akamai.net', 443),
    'tcp img.alicdn.com:443': () => _connect('img.alicdn.com', 443),
    'https api64.ipify.org': () => _get('https://api64.ipify.org', body: true),
    if (container != null) ...{
      'app plans': () => _app(container.read(lanternServiceProvider).plans()),
      'app user data': () =>
          _app(container.read(lanternServiceProvider).fetchUserData()),
    },
  };
  final results = await Future.wait(
    checks.entries.map((check) async {
      final watch = Stopwatch()..start();
      String outcome;
      try {
        outcome =
            'ok ${await check.value().timeout(const Duration(seconds: 20))}';
      } catch (e) {
        outcome = 'FAIL ${e.toString().split('\n').first}';
      }
      return 'NETDIAG [$label] ${check.key}: $outcome '
          '(${watch.elapsedMilliseconds}ms)';
    }),
  );
  results.forEach(debugPrint);
}

Future<String> _lookup(String host) async {
  final addresses = await InternetAddress.lookup(host);
  return addresses.map((a) => a.address).join(',');
}

Future<String> _get(String url, {bool body = false}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    final text = await response
        .transform(const SystemEncoding().decoder)
        .join();
    return body ? text.trim() : 'status ${response.statusCode}';
  } finally {
    client.close(force: true);
  }
}

Future<String> _connect(String host, int port) async {
  final socket = await Socket.connect(
    host,
    port,
    timeout: const Duration(seconds: 10),
  );
  final remote = socket.remoteAddress.address;
  socket.destroy();
  return remote;
}

Future<String> _app<T>(Future<Either<Failure, T>> call) async =>
    (await call).fold((failure) => throw Exception(failure.error), (_) => 'ok');
