import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

// These fields come from the pinned daemon's slog text handler. Decode quoted
// values before comparing Windows paths; the log contains escaped backslashes.
String? _attribute(String line, String name) {
  for (final match in RegExp(
    r'(?:^| )([\w.]+)=("(?:[^"\\]|\\.)*"|[^ ]+)',
  ).allMatches(line)) {
    if (match.group(1) != name) continue;
    final value = match.group(2)!;
    if (!value.startsWith('"')) return value;
    try {
      return jsonDecode(value) as String;
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// Requires one connection ID to contain the tuple, owner, rule and outbound.
Map<String, Object?>? correlateWindowsRoute(
  Iterable<String> lines, {
  required Map<String, dynamic> connection,
  required String executable,
  required String Function(String) normalizePath,
  required bool bypass,
}) {
  if (connection['pid'] is! int ||
      (connection['pid'] as int) <= 0 ||
      !['tcp', 'udp'].contains(connection['protocol']) ||
      connection['executable'] is! String ||
      normalizePath(connection['executable'] as String) !=
          normalizePath(executable)) {
    return null;
  }
  final groups = <String, List<String>>{};
  for (final line in lines) {
    final id = _attribute(line, 'id');
    if (id != null) groups.putIfAbsent(id, () => []).add(line);
  }
  final packet = connection['protocol'] == 'udp' ? 'packet ' : '';
  for (final entry in groups.entries) {
    final messages = entry.value
        .map((line) => _attribute(line, 'msg'))
        .toList();
    if (!messages.contains(
          'inbound ${packet}connection from ${connection['localAddress']}',
        ) ||
        !messages.contains(
          'inbound ${packet}connection to ${connection['remoteAddress']}',
        )) {
      continue;
    }
    final owners = messages.whereType<String>().where(
      (message) => message.startsWith('found process path: '),
    );
    if (!owners.any((message) {
      final path = message
          .substring('found process path: '.length)
          .split(RegExp(r'\s*,\s*user(?: id)?:'))
          .first
          .trim();
      return normalizePath(path) == normalizePath(executable);
    })) {
      continue;
    }
    final rules = messages.whereType<String>().where(
      (message) => RegExp(r'^match\[\s*\d+\s*\]').hasMatch(message),
    );
    final routingRules = rules.where(
      (message) => message.contains('=> route('),
    );
    if (routingRules.isEmpty) continue;
    final rule = routingRules.last;
    if (bypass
        ? !rule.contains('split-tunnel') || !rule.endsWith('=> route(direct)')
        : !RegExp(r'=> route\((auto|manual)\)$').hasMatch(rule)) {
      continue;
    }
    final outboundTags = entry.value
        .map((line) {
          final tag = _attribute(line, 'tag') ?? '';
          return tag.startsWith('outbound/') ? tag : null;
        })
        .whereType<String>()
        .toSet();
    return {
      'connectionId': entry.key,
      'connection': connection,
      'matchedRule': rule,
      // The routing action is universal; individual transports log attempts
      // differently and do not always report which proxy ultimately succeeded.
      'routedOutbound': RegExp(
        r'=> route\(([^)]+)\)$',
      ).firstMatch(rule)!.group(1),
      'outboundLogTags': outboundTags.toList(),
      'bypass': bypass,
      'logs': entry.value,
    };
  }
  return null;
}

Future<ProcessResult> _run(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, runInShell: false);
  var exited = false;
  final exitCode = process.exitCode.then((code) {
    exited = true;
    return code;
  });
  try {
    final values = await Future.wait<Object>([
      exitCode,
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.transform(utf8.decoder).join(),
    ]).timeout(const Duration(seconds: 15));
    final result = ProcessResult(
      process.pid,
      values[0] as int,
      values[1],
      values[2],
    );
    if (result.exitCode != 0) {
      throw StateError('$executable failed: ${result.stderr} ${result.stdout}');
    }
    return result;
  } finally {
    if (!exited) process.kill();
    await exitCode.timeout(const Duration(seconds: 5));
  }
}

/// Streams only connection diagnostics, not unrelated daemon settings or logs.
class WindowsRoutingEvidence {
  WindowsRoutingEvidence._(this._cli, this._directory, this._previousLevel);

  final String _cli;
  final String _directory;
  final String _previousLevel;
  final _lines = <String>[];
  Process? _tail;
  StreamSubscription<String>? _subscription;
  Future<void>? _errors;
  IOSink? _sink;

  int get mark => _lines.length;

  static Future<WindowsRoutingEvidence> start(
    String cli,
    String directory,
  ) async {
    final setting = await _run(cli, ['get', 'log-level']);
    final previous = (setting.stdout as String)
        .trim()
        .replaceFirst('log-level:', '')
        .trim();
    final evidence = WindowsRoutingEvidence._(
      cli,
      directory,
      previous.isEmpty ? 'info' : previous,
    );
    try {
      await Directory(directory).create(recursive: true);
      await _run(cli, ['set', '--log-level', 'debug']);
      evidence._sink = File(
        p.join(directory, 'daemon-connections.log'),
      ).openWrite();
      final process = await Process.start(cli, ['logs', '--level', 'debug']);
      evidence._tail = process;
      evidence._errors = process.stderr.drain<void>();
      final ready = Completer<void>();
      evidence._subscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (!ready.isCompleted) ready.complete();
              final message = _attribute(line, 'msg') ?? '';
              // Some debug records include transport configuration. Keep only
              // routing diagnostics in the uploaded artifact.
              final connectionMessage = RegExp(
                r'^(inbound (packet )?connection |found process path: |failed to search process: |(pre-)?match\[|outbound (UoT )?(packet )?connection)',
              ).hasMatch(message);
              if (_attribute(line, 'id') != null && connectionMessage) {
                evidence._lines.add(line);
                evidence._sink!.writeln(line);
              }
            },
            onError: (Object error, StackTrace stack) {
              if (!ready.isCompleted) ready.completeError(error, stack);
            },
            onDone: () {
              if (!ready.isCompleted) {
                ready.completeError(StateError('Daemon log stream closed'));
              }
            },
          );
      await ready.future.timeout(const Duration(seconds: 15));
      return evidence;
    } catch (_) {
      await evidence.close();
      rethrow;
    }
  }

  Future<void> expectRoute({
    required int since,
    required Iterable<Map<String, dynamic>> connections,
    required String executable,
    required String Function(String) normalizePath,
    required bool bypass,
    required String scenario,
    required String publicIP,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      for (final connection in connections) {
        final match = correlateWindowsRoute(
          _lines.skip(since),
          connection: connection,
          executable: executable,
          normalizePath: normalizePath,
          bypass: bypass,
        );
        if (match == null) continue;
        await File(p.join(_directory, 'routing-evidence.jsonl')).writeAsString(
          '${jsonEncode({'scenario': scenario, 'publicIP': publicIP, ...match})}\n',
          mode: FileMode.append,
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError(
      '$scenario: missing correlated owner/rule/outbound evidence for ${jsonEncode(connections.toList())} (see daemon-connections.log)',
    );
  }

  Future<void> close() async {
    try {
      _tail?.kill();
      await _tail?.exitCode.timeout(const Duration(seconds: 5));
      await _subscription?.cancel();
      await _errors;
      await _sink?.close();
    } finally {
      await _run(_cli, ['set', '--log-level', _previousLevel]);
    }
  }
}

/// Keeps the socket open while Windows independently identifies its owner.
Future<Map<String, dynamic>> probeWindowsConnection(
  String executable, {
  String? child,
  bool udp = false,
}) async {
  const ownerScript = String.fromEnvironment(
    'SPLIT_TUNNEL_SOCKET_OWNER_SCRIPT',
  );
  if (ownerScript.isEmpty) {
    throw StateError('Missing Windows socket-owner helper');
  }
  final process = await Process.start(executable, [
    if (child != null) ...['--child', child],
    '--json',
    '--wait-for-input',
    if (udp) '--udp',
  ], runInShell: false);
  var exited = false;
  final exitCode = process.exitCode.then((code) {
    exited = true;
    return code;
  });
  final lines = StreamIterator(
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );
  final errors = process.stderr.transform(utf8.decoder).join();
  try {
    if (!await lines.moveNext().timeout(const Duration(seconds: 30))) {
      throw StateError(
        'Probe exited without opening a socket: ${await errors}',
      );
    }
    final connected = jsonDecode(lines.current) as Map<String, dynamic>;
    if (connected['event'] != 'connected') {
      throw StateError('Missing connected event');
    }
    final local = Uri.parse('socket://${connected['localAddress']}');
    final remote = Uri.parse('socket://${connected['remoteAddress']}');
    final result = await _run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      ownerScript,
      '-ProcessId',
      '${connected['pid']}',
      '-Protocol',
      '${connected['protocol']}',
      '-LocalAddress',
      local.host,
      '-LocalPort',
      '${local.port}',
      '-RemoteAddress',
      remote.host,
      '-RemotePort',
      '${remote.port}',
    ]);
    final owner = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    if (owner['pid'] != connected['pid'] ||
        owner['protocol'] != connected['protocol'] ||
        (owner['localAddress'] != connected['localAddress'] &&
            !(udp && owner['localAddress'] == '0.0.0.0:${local.port}')) ||
        (!udp && owner['remoteAddress'] != connected['remoteAddress'])) {
      throw StateError('Windows endpoint owner did not match the probe');
    }
    process.stdin.writeln();
    await process.stdin.flush();
    if (!await lines.moveNext().timeout(const Duration(seconds: 30))) {
      throw StateError('Probe did not return a response: ${await errors}');
    }
    final response = jsonDecode(lines.current) as Map<String, dynamic>;
    for (final field in ['pid', 'protocol', 'localAddress', 'remoteAddress']) {
      if (response[field] != connected[field]) {
        throw StateError('Probe changed $field');
      }
    }
    if (response['event'] != 'result' ||
        InternetAddress.tryParse('${response['publicIP']}')?.type !=
            InternetAddressType.IPv4 ||
        await exitCode.timeout(const Duration(seconds: 5)) != 0) {
      throw StateError('Invalid probe response: $response ${await errors}');
    }
    return {
      ...response,
      'executable': owner['executable'],
      'windowsOwner': owner,
    };
  } finally {
    await lines.cancel();
    await process.stdin.close();
    if (!exited) {
      await exitCode.timeout(const Duration(seconds: 1), onTimeout: () => -1);
    }
    if (!exited) {
      await _run('taskkill.exe', [
        '/PID',
        '${process.pid}',
        '/T',
        '/F',
      ]).catchError((Object _) => ProcessResult(process.pid, 0, '', ''));
      process.kill();
    }
    await exitCode.timeout(const Duration(seconds: 5));
    await errors;
  }
}
