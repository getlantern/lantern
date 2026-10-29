import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef FirefoxProbeResult = ({
  String address,
  int browserPid,
  List<Map<String, dynamic>> connections,
});

/// Uses a fresh browser process so a rule change cannot reuse an old connection.
Future<FirefoxProbeResult> probeFirefox({
  required String firefoxPath,
  required String geckodriverPath,
  String? artifactDirectory,
}) async {
  if (!Platform.isWindows) throw UnsupportedError('Windows Firefox smoke');
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
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..findProxy = (_) => 'DIRECT';
  final subscriptions = <StreamSubscription<String>>[];
  Process? driver;
  Process? observer;
  String? session;
  var driverExited = false;
  var port = 0;

  Stream<String> lines(Stream<List<int>> stream) =>
      stream.transform(utf8.decoder).transform(const LineSplitter());

  Future<dynamic> command(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = await client.openUrl(
      method,
      Uri.http('127.0.0.1:$port', path),
    );
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 45));
    final decoded =
        jsonDecode(
              await utf8.decoder
                  .bind(response)
                  .join()
                  .timeout(const Duration(seconds: 5)),
            )
            as Map<String, dynamic>;
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('WebDriver $method $path failed: ${decoded['value']}');
    }
    return decoded['value'];
  }

  try {
    driver = await Process.start(geckodriverPath, [
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
    for (final stream in [driver.stdout, driver.stderr]) {
      subscriptions.add(
        lines(stream).listen(
          (line) {
            log.writeln(line);
            final match = RegExp(
              r'Listening on 127\.0\.0\.1:(\d+)',
            ).firstMatch(line);
            if (match != null && !listening.isCompleted) {
              listening.complete(int.parse(match[1]!));
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!listening.isCompleted) listening.completeError(error, stack);
          },
        ),
      );
    }
    unawaited(
      driver.exitCode.then((code) {
        driverExited = true;
        if (!listening.isCompleted) {
          listening.completeError(StateError('GeckoDriver exited with $code'));
        }
      }),
    );
    port = await listening.future.timeout(const Duration(seconds: 15));
    final created = await command('POST', '/session', {
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
    final errors = <String>[];
    final ready = Completer<void>();
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
      lines(observer.stdout).listen((line) {
        try {
          final value = jsonDecode(line) as Map<String, dynamic>;
          if (value['ready'] == true) {
            if (!ready.isCompleted) ready.complete();
          } else {
            observed[line] = value;
            log.writeln('Windows socket owner: $line');
          }
        } catch (error) {
          errors.add('Invalid socket observation: $error');
        }
      }, onError: (Object error) => errors.add('$error')),
    );
    subscriptions.add(lines(observer.stderr).listen(errors.add));
    await ready.future.timeout(const Duration(seconds: 15));
    await command('POST', '/session/$session/url', {
      'url':
          'https://api4.ipify.org/?lantern-smoke=${DateTime.now().microsecondsSinceEpoch}',
    });
    final value = await command('POST', '/session/$session/execute/sync', {
      'script': 'return document.body.innerText;',
      'args': [],
    });
    final address = value is String
        ? InternetAddress.tryParse(value.trim())
        : null;
    if (address?.type != InternetAddressType.IPv4) {
      throw FormatException('Firefox returned an invalid IPv4 address: $value');
    }
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (observed.isEmpty &&
        errors.isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (errors.isNotEmpty || observed.isEmpty) {
      throw StateError(
        'No independently owned Firefox HTTPS connection: ${errors.join('\n')}',
      );
    }
    return (
      address: address!.address,
      browserPid: browserPid,
      connections: observed.values.toList(),
    );
  } finally {
    observer?.kill();
    if (session != null && !driverExited) {
      try {
        await command(
          'DELETE',
          '/session/$session',
        ).timeout(const Duration(seconds: 10));
      } catch (error) {
        log.writeln('Firefox session cleanup: $error');
      }
    }
    client.close(force: true);
    if (driver != null && !driverExited) {
      try {
        await Process.run('taskkill.exe', [
          '/PID',
          '${driver.pid}',
          '/T',
          '/F',
        ]).timeout(const Duration(seconds: 10));
      } catch (error) {
        log.writeln('GeckoDriver process cleanup: $error');
      } finally {
        driver.kill();
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
