import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/vpn/windows_routing_evidence.dart';

void main() {
  const executable = r'C:\Game Files 遊戲\Game.exe';
  final connection = <String, dynamic>{
    'pid': 42,
    'executable': executable,
    'protocol': 'tcp',
    'localAddress': '172.16.0.2:50420',
    'remoteAddress': '198.51.100.2:443',
  };
  String log(String message, {int id = 123, String tag = 'router'}) =>
      'time=2026-10-24T12:00:00Z level=DEBUG msg=${jsonEncode(message)} tag=$tag id=$id duration=1ms';
  List<String> logs({bool udp = false, bool bypass = true}) {
    final packet = udp ? 'packet ' : '';
    return [
      log(
        'inbound ${packet}connection from ${connection['localAddress']}',
        tag: 'inbound/tun[tun-in]',
      ),
      log(
        'inbound ${packet}connection to ${connection['remoteAddress']}',
        tag: 'inbound/tun[tun-in]',
      ),
      log('found process path: $executable , user: runner'),
      log('match[ 0 ] => sniff'),
      log(
        bypass
            ? 'match[ 4 ] rule_set=split-tunnel => route(direct)'
            : 'match[ 8 ] clash_mode=auto => route(auto)',
      ),
      log(
        'outbound ${packet}connection to ${connection['remoteAddress']}',
        tag: bypass
            ? 'outbound/direct[direct]'
            : 'outbound/hysteria2[test-proxy]',
      ),
    ];
  }

  Map<String, Object?>? correlate(
    List<String> lines, {
    Map<String, dynamic>? owner,
    bool bypass = true,
  }) => correlateWindowsRoute(
    lines,
    connection: owner ?? connection,
    executable: executable,
    normalizePath: (path) => path.toLowerCase(),
    bypass: bypass,
  );

  test(
    'correlates TCP and UDP ownership, routing rule and selected outbound',
    () {
      for (final udp in [false, true]) {
        for (final bypass in [false, true]) {
          final evidence = correlate(
            logs(udp: udp, bypass: bypass),
            owner: {...connection, 'protocol': udp ? 'udp' : 'tcp'},
            bypass: bypass,
          );
          expect(evidence?['connectionId'], '123');
          expect(evidence?['bypass'], bypass);
          expect(evidence?['routedOutbound'], bypass ? 'direct' : 'auto');
          expect(evidence?['connection'], containsPair('pid', 42));
        }
      }
    },
  );

  test('cannot borrow evidence from another connection ID', () {
    final complete = logs();
    for (var index = 0; index < 5; index++) {
      if (index == 3) continue; // Sniffing is not the routing decision.
      final mixed = [...complete];
      mixed[index] = mixed[index].replaceFirst('id=123', 'id=456');
      expect(correlate(mixed), isNull, reason: 'borrowed evidence at $index');
    }
  });

  test('rejects a wrong source, destination, owner, PID or protocol', () {
    for (final update in <Map<String, dynamic>>[
      {'localAddress': '172.16.0.2:50421'},
      {'remoteAddress': '198.51.100.3:443'},
      {'executable': r'C:\Other Game\Game.exe'},
      {'pid': 0},
      {'protocol': 'udp'},
      {'protocol': 'icmp'},
    ]) {
      expect(correlate(logs(), owner: {...connection, ...update}), isNull);
    }
    expect(
      correlate(
        logs().map((line) => line.replaceAll('Game.exe', 'Other.exe')).toList(),
      ),
      isNull,
    );
  });

  test('requires the final route decision, not a sniff or unrelated rule', () {
    expect(correlate(logs().sublist(0, 4)), isNull);
    expect(correlate(logs(bypass: false)), isNull);
    expect(correlate(logs(), bypass: false), isNull);
    expect(
      correlate(
        logs()
            .map(
              (line) => line.replaceAll(
                'rule_set=split-tunnel',
                'ip_is_private=true',
              ),
            )
            .toList(),
      ),
      isNull,
    );
    expect(
      correlate([...logs(), log('match[ 8 ] clash_mode=auto => route(auto)')]),
      isNull,
    );
  });

  test(
    'does not require transport-specific logs or mistake attempts for the winning proxy',
    () {
      final evidence = correlate(
        logs(bypass: false).sublist(0, 5),
        bypass: false,
      );
      expect(evidence?['routedOutbound'], 'auto');
      expect(evidence?['outboundLogTags'], isEmpty);
    },
  );

  test(
    'attribute-like text inside a Windows filename is not a log attribute',
    () {
      const path = r'C:\Game id=999 tag=other\Game.exe';
      final entries = logs();
      entries[2] = log('found process path: $path , user id: 10');
      final evidence = correlateWindowsRoute(
        entries,
        connection: {...connection, 'executable': path},
        executable: path,
        normalizePath: (value) => value.toLowerCase(),
        bypass: true,
      );
      expect(evidence?['connectionId'], '123');
    },
  );

  test(
    'does not confuse pre-match, another protocol or truncated log lines',
    () {
      expect(
        correlate(
          logs()
              .map((line) => line.replaceAll('match[', 'pre-match['))
              .toList(),
        ),
        isNull,
      );
      expect(correlate(logs(udp: true)), isNull);
      expect(correlate(['msg="broken id=123']), isNull);
    },
  );
}
