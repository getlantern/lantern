import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/vpn/split_tunneling_smoke_helpers.dart';

void main() {
  test('prefers the daemon rule file over legacy client files', () {
    expect(
      splitTunnelRuleFileCandidates(
        environment: {
          'ProgramData': r'C:\ProgramData',
          'PUBLIC': r'C:\Users\Public',
          'LOCALAPPDATA': r'C:\Users\runner\AppData\Local',
        },
      ),
      [
        r'C:\ProgramData\Lantern\split-tunnel.json',
        r'C:\Users\Public\Lantern\data\split-tunnel.json',
        r'C:\ProgramData\Lantern\data\split-tunnel.json',
        r'C:\Users\runner\AppData\Local\Lantern\data\split-tunnel.json',
      ],
    );
  });

  test('uses redirected Windows directories with trailing separators', () {
    final candidates = splitTunnelRuleFileCandidates(
      environment: {
        'ProgramData': 'D:\\Shared Data\\',
        'PUBLIC': 'D:\\Public\\',
      },
    );
    expect(candidates.first, r'D:\Shared Data\Lantern\split-tunnel.json');
    expect(candidates, contains(r'D:\Public\Lantern\data\split-tunnel.json'));
  });

  test('does not build relative paths from missing environment values', () {
    for (final environment in [
      <String, String>{},
      {'ProgramData': '', 'PUBLIC': '', 'LOCALAPPDATA': ''},
    ]) {
      expect(splitTunnelRuleFileCandidates(environment: environment), [
        r'C:\Users\Public\Lantern\data\split-tunnel.json',
      ]);
    }
  });

  test('reads the active file before a stale legacy file', () async {
    final directory = await Directory.systemTemp.createTemp('split-tunnel-');
    addTearDown(() => directory.delete(recursive: true));
    final active = File.fromUri(directory.uri.resolve('active.json'));
    final legacy = File.fromUri(directory.uri.resolve('legacy.json'));
    final paths = [active.path, legacy.path];

    expect(await readSplitTunnelConfigFromDisk(paths: paths), isNull);
    await legacy.writeAsString('{"rules":[]}');
    expect(
      (await readSplitTunnelConfigFromDisk(paths: paths))?.key,
      legacy.path,
    );

    final current = jsonEncode({
      'rules': [
        {'process_path': r'C:\Games\Game.exe'},
      ],
    });
    await active.writeAsString(current);
    final snapshot = await readSplitTunnelConfigFromDisk(paths: paths);
    expect(snapshot?.key, active.path);
    expect(snapshot?.value, current);
  });

  test('reads nested rule values without matching other fields', () {
    final config = jsonEncode({
      'version': 3,
      'rules': [
        {
          'type': 'logical',
          'rules': [
            {
              'domain_suffix': ['api64.ipify.org'],
            },
            {'process_path': r'C:\Game Files\Game.exe'},
            {
              'process_path_regex': [r'C:\Other Game\.*'],
            },
          ],
        },
      ],
      'metadata': {
        'domain_suffix': ['not-a-rule.example'],
      },
    });
    expect(splitTunnelRuleValues(config, 'domain_suffix'), {'api64.ipify.org'});
    expect(splitTunnelRuleValues(config, 'process_path'), {
      r'C:\Game Files\Game.exe',
    });
  });

  test('distinguishes an empty rule set from invalid configuration', () {
    expect(splitTunnelRuleValues('{"rules":[]}', 'process_path'), isEmpty);
    for (final content in ['', '{', '[]', '{}', '{"rules":null}']) {
      expect(splitTunnelRuleValues(content, 'process_path'), isNull);
    }
  });
}
