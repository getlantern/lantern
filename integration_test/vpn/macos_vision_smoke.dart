import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_service.dart';

import 'connect_smoke_harness.dart';
import 'vpn_smoke_helpers.dart';

const _downloadBytes = 1024 * 1024;
const _downloadHost = 'speed.cloudflare.com';

Future<void> runMacosVisionSmoke(WidgetTester tester) async {
  final finders = VpnSmokeFinders();
  final states = VpnStateFinders();
  // Read the credential at runtime; signed fixtures must not contain it.
  final configFile = File('/Users/Shared/Lantern/E2E/vision-server-urls');
  var configUrl = (await configFile.readAsString()).trim();
  await configFile.delete();
  final curlFile = File('/Users/Shared/Lantern/E2E/vision-curl-path');
  final curlExecutable = (await curlFile.readAsString()).trim();
  await curlFile.delete();
  final serverName = 'ci-vision-${DateTime.now().microsecondsSinceEpoch}';
  configUrl = '${configUrl.split('#').first}#$serverName';

  var tags = <String>[];
  var importAttempted = false;
  try {
    // The extension owns the IPC socket, so import while it is running.
    await runConnectSmokeHarness(
      tester,
      enableIpCheck: true,
      requireIpRestored: true,
      afterConnect: () async {
        importAttempted = true;
        final imported = await _requestIPC(
          '/servers/urls',
          body: {
            'urls': [configUrl],
            'skipCertVerification': false,
          },
        );
        tags = (imported as List).cast<String>();
      },
    );
    expect(tags.length, 1, reason: 'The smoke requires one private server');
    final tag = tags.single;
    final lantern = sl<LanternService>();
    for (var cycle = 1; cycle <= 3; cycle++) {
      final baseline = await fetchPublicIpForSmoke(
        timeout: const Duration(seconds: 40),
        reason: 'before Vision cycle $cycle',
      );
      try {
        final connect = await lantern.connectToServer(
          ServerLocationType.privateServer.name,
          tag,
        );
        expect(connect.isRight(), isTrue, reason: 'Vision connection failed');
        await states.waitFor(
          tester,
          expected: const [VPNStatus.connected],
          timeout: const Duration(seconds: 60),
          reason: 'VLESS-Vision did not connect',
        );

        final selected = await _requestIPC('/server/selected') as Map;
        expect(selected['exists'], isTrue);
        expect((selected['server'] as Map)['tag'] == tag, isTrue);
        // Manual selection omits outbound options, so read the server itself.
        final server =
            await _requestIPC('/servers', query: {'tag': tag}) as Map;
        expect(
          isVerifiedVisionServer(server),
          isTrue,
          reason: 'The selected outbound must use Vision with verified TLS',
        );
        final connected = await fetchPublicIpForSmoke(
          timeout: const Duration(seconds: 40),
          reason: 'during Vision cycle $cycle',
        );
        expect(
          connected != baseline,
          isTrue,
          reason: 'Public IP did not change through the Vision server',
        );
        await _verifyVisionDownload(tag, curlExecutable);
        await tester.pump();
        expect(states.current(), VPNStatus.connected);
        debugPrint(
          'VLESS-Vision smoke: cycle $cycle/3 transferred 1 MiB '
          'through the selected TUN outbound',
        );
      } finally {
        await disconnectVpnForSmoke(
          tester,
          vpnToggle: finders.vpnToggle,
          vpnStateFinders: states,
        );
      }
      await expectPublicIpRestored(baseline);
    }
  } finally {
    for (final tag in {if (importAttempted) serverName, ...tags}) {
      final removed = await sl<LanternService>().deletePrivateServerByName(tag);
      expect(
        removed.isRight(),
        isTrue,
        reason: 'Could not remove the private smoke server',
      );
    }
  }
}

bool isVerifiedVisionServer(Map server) {
  final outbound = server['outbound'];
  if (outbound is! Map) return false;
  final tls = outbound['tls'];
  return outbound['type'] == 'vless' &&
      outbound['flow'] == 'xtls-rprx-vision' &&
      tls is Map &&
      tls['enabled'] == true &&
      tls['insecure'] != true;
}

bool hasVisionTraffic(List connections, String tag) {
  return connections.whereType<Map>().any(
    (connection) =>
        connection['inbound'] == 'tun/tun-in' &&
        connection['outbound'] == 'vless/$tag' &&
        connection['network'] == 'tcp' &&
        connection['domain'] == _downloadHost &&
        (connection['downlink'] as num? ?? 0) >= 8192,
  );
}

Future<dynamic> _requestIPC(
  String path, {
  Map<String, String>? query,
  Map<String, dynamic>? body,
}) async {
  final process = await Process.start('/usr/bin/curl', [
    '--silent',
    '--fail',
    '--max-time',
    '10',
    '--noproxy',
    '*',
    '--http2-prior-knowledge',
    '--unix-socket',
    '/var/run/lantern/lanternd.sock',
    if (body != null) ...[
      '--header',
      'Content-Type: application/json',
      '--data-binary',
      '@-',
    ],
    Uri.http('lantern', path, query).toString(),
  ]);
  final output = process.stdout.transform(utf8.decoder).join();
  final stderrDone = process.stderr.drain<void>();
  try {
    if (body != null) process.stdin.write(jsonEncode(body));
    await process.stdin.close();
    final response = await output;
    await stderrDone;
    if (await process.exitCode != 0) fail('Smoke IPC request failed: $path');
    try {
      return jsonDecode(response);
    } on FormatException {
      fail('Invalid smoke metadata from $path');
    }
  } finally {
    process.kill();
    await process.exitCode;
  }
}

Future<void> _verifyVisionDownload(String tag, String curlExecutable) async {
  final directory = await Directory.systemTemp.createTemp('lantern-vision-');
  Process? download;
  try {
    final output = File('${directory.path}/download');
    // Keep the transfer open long enough to observe its route in Radiance.
    download = await Process.start(curlExecutable, [
      '--silent',
      '--show-error',
      '--fail',
      '--noproxy',
      '*',
      '--tlsv1.3',
      '--max-time',
      '60',
      '--limit-rate',
      '64k',
      '--output',
      output.path,
      'https://$_downloadHost/__down?bytes=$_downloadBytes',
    ]);
    final stdoutDone = download.stdout.drain<void>();
    final stderrDone = download.stderr.transform(utf8.decoder).join();
    int? exitCode;
    final exited = download.exitCode.then((code) => exitCode = code);
    var observed = false;
    while (exitCode == null && !observed) {
      observed = hasVisionTraffic(
        await _requestIPC('/vpn/connections') as List,
        tag,
      );
      if (!observed) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    await exited;
    await stdoutDone;
    final stderr = await stderrDone;
    expect(
      exitCode,
      0,
      reason: 'The HTTPS download through Vision failed: $stderr',
    );
    expect(
      await output.length(),
      _downloadBytes,
      reason: 'The Vision download was incomplete',
    );
    expect(
      observed,
      isTrue,
      reason: 'No TUN traffic was observed through the selected Vision server',
    );
  } finally {
    download?.kill();
    if (download != null) await download.exitCode;
    await directory.delete(recursive: true);
  }
}
