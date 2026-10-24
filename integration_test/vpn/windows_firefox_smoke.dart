import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FirefoxProbeResult {
  FirefoxProbeResult({
    required this.address,
    required this.browserPid,
    required this.connections,
  });

  final String address;
  final int browserPid;
  final List<Map<String, dynamic>> connections;

  Map<String, dynamic> toJson() => {
    'address': address,
    'browserPid': browserPid,
    'connections': connections,
  };
}

/// The small WebDriver subset used by the installed-Firefox smoke test.
class FirefoxWebDriver {
  FirefoxWebDriver(this.endpoint) {
    if (endpoint.scheme != 'http' || endpoint.host != '127.0.0.1') {
      throw ArgumentError('WebDriver must listen on IPv4 loopback');
    }
  }

  final Uri endpoint;
  final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..findProxy = (_) => 'DIRECT';

  Future<dynamic> command(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = endpoint.resolve(path);
    if (uri.origin != endpoint.origin) {
      throw ArgumentError('WebDriver commands must stay on loopback');
    }
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 45));
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 5))) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('Unexpectedly large WebDriver response');
      }
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('value')) {
      throw const FormatException('Invalid WebDriver response');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('WebDriver $method $path failed: ${decoded['value']}');
    }
    return decoded['value'];
  }

  void close() => _client.close(force: true);
}

String firefoxProbeAddress(dynamic value) {
  if (value is! String) {
    throw const FormatException('Firefox did not return an address');
  }
  final address = InternetAddress.tryParse(value.trim());
  if (address == null || address.type != InternetAddressType.IPv4) {
    throw FormatException('Firefox returned an invalid IPv4 address: $value');
  }
  return address.address;
}

/// Uses a fresh browser process so a rule change cannot reuse an old connection.
Future<FirefoxProbeResult> probeFirefox({
  required String firefoxPath,
  required String geckodriverPath,
  String? artifactDirectory,
}) async {
  if (!Platform.isWindows) throw UnsupportedError('Windows Firefox smoke');
  for (final path in [firefoxPath, geckodriverPath]) {
    if (!File(path).existsSync()) {
      throw ArgumentError('Missing executable: $path');
    }
  }
  final targets =
      (await InternetAddress.lookup(
            'api4.ipify.org',
            type: InternetAddressType.IPv4,
          ).timeout(const Duration(seconds: 15)))
          .map((address) => address.address)
          .toSet();
  if (targets.isEmpty) throw StateError('No IPv4 address for api4.ipify.org');

  final directory = await Directory.systemTemp.createTemp('lantern-firefox-');
  final log = StringBuffer('IPify targets: ${targets.join(', ')}\n');
  Process? driverProcess;
  Process? observer;
  FirefoxWebDriver? driver;
  String? session;
  var driverExited = false;
  final subscriptions = <StreamSubscription<String>>[];
  try {
    driverProcess = await Process.start(geckodriverPath, [
      '--host',
      '127.0.0.1',
      '--port',
      '0',
      '--profile-root',
      directory.path,
      '--log',
      'info',
    ]);
    final listening = Completer<int>();
    void driverLine(String line) {
      log.writeln(line);
      final match = RegExp(r'Listening on 127\.0\.0\.1:(\d+)').firstMatch(line);
      if (match != null && !listening.isCompleted) {
        listening.complete(int.parse(match[1]!));
      }
    }

    for (final stream in [driverProcess.stdout, driverProcess.stderr]) {
      subscriptions.add(
        stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              driverLine,
              onError: (Object error, StackTrace stack) {
                if (!listening.isCompleted) {
                  listening.completeError(error, stack);
                }
              },
            ),
      );
    }
    unawaited(
      driverProcess.exitCode.then((code) {
        driverExited = true;
        if (!listening.isCompleted) {
          listening.completeError(StateError('GeckoDriver exited with $code'));
        }
      }),
    );
    final port = await listening.future.timeout(const Duration(seconds: 15));
    driver = FirefoxWebDriver(Uri.parse('http://127.0.0.1:$port/'));
    final created = await driver.command('POST', 'session', {
      'capabilities': {
        'alwaysMatch': {
          'browserName': 'firefox',
          'acceptInsecureCerts': false,
          'timeouts': {'pageLoad': 30000, 'script': 10000},
          'moz:firefoxOptions': {
            'binary': firefoxPath,
            'args': ['-headless'],
            'prefs': {
              'network.http.http3.enable': false,
              'network.trr.mode': 5,
              'network.dns.disableIPv6': true,
              'network.proxy.type': 0,
              'network.prefetch-next': false,
              'network.http.speculative-parallel-limit': 0,
              'browser.cache.disk.enable': false,
              'browser.cache.memory.enable': false,
              'network.captive-portal-service.enabled': false,
              'network.connectivity-service.enabled': false,
            },
          },
        },
      },
    });
    session = created['sessionId'] as String;
    final browserPid = created['capabilities']['moz:processID'] as int;
    final observed = <String, Map<String, dynamic>>{};
    final ready = Completer<void>();
    final observationError = <String>[];
    observer = await Process.start(
      'powershell.exe',
      ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', _observeFirefox],
      environment: {
        'LANTERN_FIREFOX_PID': '$browserPid',
        'LANTERN_FIREFOX_PATH': firefoxPath,
        'LANTERN_FIREFOX_TARGETS': targets.join(','),
      },
    );
    subscriptions.add(
      observer.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            try {
              final value = jsonDecode(line) as Map<String, dynamic>;
              if (value['ready'] == true) {
                if (!ready.isCompleted) ready.complete();
              } else {
                observed[jsonEncode(value)] = value;
                log.writeln('Windows socket owner: $line');
              }
            } catch (error) {
              observationError.add('Invalid socket observation: $error');
            }
          }),
    );
    subscriptions.add(
      observer.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(observationError.add),
    );
    await ready.future.timeout(const Duration(seconds: 15));
    await driver.command('POST', 'session/$session/url', {
      'url':
          'https://api4.ipify.org/?lantern-smoke=${DateTime.now().microsecondsSinceEpoch}',
    });
    final address = firefoxProbeAddress(
      await driver.command('POST', 'session/$session/execute/sync', {
        'script': 'return document.body.innerText;',
        'args': [],
      }),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (observed.isEmpty &&
        observationError.isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (observationError.isNotEmpty || observed.isEmpty) {
      throw StateError(
        'No independently owned Firefox HTTPS connection: '
        '${observationError.join('\n')}',
      );
    }
    return FirefoxProbeResult(
      address: address,
      browserPid: browserPid,
      connections: observed.values.toList(),
    );
  } finally {
    observer?.kill();
    if (session != null && driver != null && !driverExited) {
      try {
        await driver
            .command('DELETE', 'session/$session')
            .timeout(const Duration(seconds: 10));
      } catch (error) {
        log.writeln('Firefox session cleanup: $error');
      }
    }
    driver?.close();
    if (driverProcess != null && !driverExited) {
      try {
        await Process.run('taskkill.exe', [
          '/PID',
          '${driverProcess.pid}',
          '/T',
          '/F',
        ]).timeout(const Duration(seconds: 10));
      } catch (error) {
        log.writeln('GeckoDriver process cleanup: $error');
      } finally {
        driverProcess.kill();
      }
    }
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    if (artifactDirectory != null && artifactDirectory.isNotEmpty) {
      final artifacts = Directory(artifactDirectory);
      await artifacts.create(recursive: true);
      await File.fromUri(
        artifacts.uri.resolve(
          'firefox-${DateTime.now().microsecondsSinceEpoch}.log',
        ),
      ).writeAsString(log.toString());
    }
    try {
      await directory.delete(recursive: true);
    } on FileSystemException catch (error) {
      stderr.writeln('Firefox temporary profile cleanup: $error');
    }
  }
}

// Socket ownership comes from Windows, independently of Lantern's route logs.
const _observeFirefox = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$rootPid = [int]$env:LANTERN_FIREFOX_PID
$targets = $env:LANTERN_FIREFOX_TARGETS.Split(',')
$seen = [System.Collections.Generic.HashSet[string]]::new()
$deadline = [DateTime]::UtcNow.AddSeconds(45)
Write-Output '{"ready":true}'
while ([DateTime]::UtcNow -lt $deadline) {
    $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'firefox.exe'")
    $owned = [System.Collections.Generic.HashSet[uint32]]::new()
    [void]$owned.Add($rootPid)
    do {
        $changed = $false
        foreach ($process in $processes) {
            if ($owned.Contains([uint32]$process.ParentProcessId)) {
                if ($owned.Add([uint32]$process.ProcessId)) { $changed = $true }
            }
        }
    } while ($changed)
    $connections = @(Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object {
        $_.State -eq 'Established' -and $_.RemotePort -eq 443 -and
        $_.RemoteAddress -in $targets -and $owned.Contains([uint32]$_.OwningProcess)
    })
    foreach ($connection in $connections) {
        $owner = $processes | Where-Object { $_.ProcessId -eq $connection.OwningProcess } | Select-Object -First 1
        if ($null -eq $owner -or -not [StringComparer]::OrdinalIgnoreCase.Equals(
            $owner.ExecutablePath, $env:LANTERN_FIREFOX_PATH)) { continue }
        $record = [ordered]@{
            pid = [int]$connection.OwningProcess
            executable = $owner.ExecutablePath
            protocol = 'tcp'
            localAddress = "$($connection.LocalAddress):$($connection.LocalPort)"
            remoteAddress = "$($connection.RemoteAddress):$($connection.RemotePort)"
        } | ConvertTo-Json -Compress
        if ($seen.Add($record)) { Write-Output $record }
    }
    Start-Sleep -Milliseconds 200
}
''';
