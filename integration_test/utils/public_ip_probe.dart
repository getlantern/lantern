import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the public IP from a probe outside Lantern's process. Lantern
/// excludes its own process from the VPN, so a check from the app itself never
/// sees the tunnel. Android only: the androidTest runner serves this channel.
const _channel = MethodChannel('org.getlantern.lantern.test/public_ip');

typedef PublicIp = ({bool vpn, String ip});

/// Probes until [condition] holds, retrying failures (the network switches
/// during connect and disconnect), and fails with the last result after
/// [timeout].
Future<PublicIp> awaitPublicIp(
  String description,
  bool Function(PublicIp) condition, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? last;
  while (DateTime.now().isBefore(deadline)) {
    final result = await _channel.invokeMapMethod<String, Object?>('probe');
    final error = result?['error'];
    final ip = result?['ip'];
    if (error == null && ip is String && ip.isNotEmpty) {
      final probe = (vpn: result?['vpn'] == true, ip: ip);
      if (condition(probe)) return probe;
      last = probe;
    } else {
      last = error;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('Timed out waiting for $description; last probe: $last');
}
