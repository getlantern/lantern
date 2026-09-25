import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';

AppData _app({
  required String name,
  required String bundleId,
  required String appPath,
  String iconPath = '',
  Uint8List? iconBytes,
  int lastUpdateTime = 0,
}) {
  return AppData(
    name: name,
    bundleId: bundleId,
    appPath: appPath,
    iconPath: iconPath,
    iconBytes: iconBytes,
    lastUpdateTime: lastUpdateTime,
  );
}

void main() {
  _macOSRuleTests();
  _indexTests();
  test('pickPreferredAppEntry prefers app with icon metadata', () {
    final current = _app(
      name: 'Sample',
      bundleId: 'com.example.sample',
      appPath: '/Applications/Sample.app',
    );
    final candidate = _app(
      name: 'Sample',
      bundleId: 'com.example.sample',
      appPath: '/Applications/Sample.app',
      iconPath: '/Applications/Sample.app/icon.png',
    );

    final preferred = pickPreferredAppEntry(current, candidate);

    expect(preferred, same(candidate));
  });

  test(
    'pickPreferredAppEntry prefers newer update when icon richness matches',
    () {
      final current = _app(
        name: 'Sample',
        bundleId: 'com.example.sample',
        appPath: '/Applications/Sample.app',
        lastUpdateTime: 100,
      );
      final candidate = _app(
        name: 'Sample',
        bundleId: 'com.example.sample',
        appPath: '/Applications/Sample.app',
        lastUpdateTime: 200,
      );

      final preferred = pickPreferredAppEntry(current, candidate);

      expect(preferred, same(candidate));
    },
  );

  test('dedupeAndSortApps excludes Lantern and keeps richer duplicate', () {
    final apps = [
      _app(
        name: 'Beta',
        bundleId: 'com.example.beta',
        appPath: '/Applications/Beta.app',
        lastUpdateTime: 10,
      ),
      _app(
        name: 'Beta',
        bundleId: 'com.example.beta',
        appPath: '/Applications/Beta.app',
        iconPath: '/Applications/Beta.app/icon.png',
        lastUpdateTime: 11,
      ),
      _app(
        name: 'Lantern',
        bundleId: 'org.getlantern.lantern',
        appPath: '/Applications/Lantern.app',
      ),
      _app(
        name: 'Alpha',
        bundleId: 'com.example.alpha',
        appPath: '/Applications/Alpha.app',
      ),
    ];

    final deduped = dedupeAndSortApps(apps);

    expect(deduped.map((a) => a.name).toList(), ['Alpha', 'Beta']);
    expect(deduped[1].iconPath, isNotEmpty);
  });

  test('dedupeAndSortApps orders display names case-insensitively', () {
    final apps = [
      _app(
        name: 'Word',
        bundleId: 'word',
        appPath: r'C:\Program Files\Microsoft Office\winword.exe',
      ),
      _app(
        name: 'chatgpt',
        bundleId: 'chatgpt',
        appPath: r'C:\Users\user\AppData\Local\ChatGPT\chatgpt.exe',
      ),
      _app(
        name: 'Access',
        bundleId: 'access',
        appPath: r'C:\Program Files\Microsoft Office\msaccess.exe',
      ),
      _app(
        name: '1Password',
        bundleId: '1password',
        appPath: r'C:\Program Files\1Password\1Password.exe',
      ),
      _app(
        name: 'ms-teams',
        bundleId: 'ms-teams',
        appPath: r'C:\Program Files\WindowsApps\ms-teams.exe',
      ),
    ];

    final sorted = dedupeAndSortApps(apps, excludeLantern: false);

    expect(sorted.map((a) => a.name).toList(), [
      '1Password',
      'Access',
      'chatgpt',
      'ms-teams',
      'Word',
    ]);
  });

  test('dedupeAndSortApps can keep Lantern entries when requested', () {
    final apps = [
      _app(
        name: 'Lantern',
        bundleId: 'org.getlantern.lantern',
        appPath: '/Applications/Lantern.app',
      ),
    ];

    final deduped = dedupeAndSortApps(apps, excludeLantern: false);

    expect(deduped, hasLength(1));
    expect(deduped.single.name, 'Lantern');
  });
}

void _indexTests() {
  test('appIndexLetter uppercases A-Z and buckets everything else under #', () {
    expect(
      appIndexLetter(_app(name: 'chrome', bundleId: 'a', appPath: '/a')),
      'C',
    );
    expect(
      appIndexLetter(_app(name: 'Zoom', bundleId: 'b', appPath: '/b')),
      'Z',
    );
    expect(
      appIndexLetter(_app(name: '1Password', bundleId: 'c', appPath: '/c')),
      '#',
    );
    expect(
      appIndexLetter(_app(name: 'Éclair', bundleId: 'd', appPath: '/d')),
      '#',
    );
    expect(appIndexLetter(_app(name: '  ', bundleId: 'e', appPath: '/e')), '#');
    // Uppercases to "SS"; must not leak a multi-character key.
    expect(
      appIndexLetter(_app(name: 'ßeta', bundleId: 'f', appPath: '/f')),
      '#',
    );
  });

  test('groupAppsByLetter keeps letter order with # first', () {
    final apps = dedupeAndSortApps([
      _app(name: 'Brave', bundleId: 'com.brave', appPath: '/brave'),
      _app(name: '~tilde', bundleId: 'com.tilde', appPath: '/tilde'),
      _app(name: 'calendar', bundleId: 'com.cal', appPath: '/cal'),
      _app(name: 'Chrome', bundleId: 'com.chrome', appPath: '/chrome'),
      _app(name: '1Password', bundleId: 'com.1p', appPath: '/1p'),
    ]);

    final groups = groupAppsByLetter(apps);
    expect(groups.keys.toList(), ['#', 'B', 'C']);
    expect(groups['#']!.map((a) => a.name), ['1Password', '~tilde']);
    expect(groups['C']!.map((a) => a.name), ['calendar', 'Chrome']);
    expect(groupAppsByLetter(const []), isEmpty);
  });
}

void _macOSRuleTests() {
  test('macOSSplitTunnelRule keeps the Contents rule for native bundles', () {
    final app = _app(
      name: 'Firefox',
      bundleId: 'org.mozilla.firefox',
      appPath: '/Applications/Firefox.app',
    );
    expect(macOSSplitTunnelRule(app), '/Applications/Firefox.app/Contents/.*');
  });

  test('macOSSplitTunnelRule matches iPhone/iPad apps on the inner bundle', () {
    final app = _app(
      name: 'Stream',
      bundleId: 'com.fish.stream',
      appPath: '/Applications/Stream.app',
    ).copyWith(wrappedBundle: 'NetworkSniffer.app');

    final rule = macOSSplitTunnelRule(app);
    expect(rule, r'/Wrapper/NetworkSniffer\.app/.*');

    // The path macOS actually runs the app from (observed on macOS 26).
    const translocated =
        '/private/var/folders/v0/7k3mc29n0g3g_t5kw4fpp0yc0000gn/X/'
        '1A83308F-8D8A-528B-ABB7-839ECC657228/d/Wrapper/NetworkSniffer.app/NetworkSniffer';
    expect(RegExp(rule).hasMatch(translocated), isTrue);
    expect(
      RegExp(rule).hasMatch(
        '/Applications/Stream.app/Wrapper/NetworkSniffer.app/NetworkSniffer',
      ),
      isTrue,
    );
    expect(
      RegExp(rule).hasMatch('/Applications/Stream.app/Contents/MacOS/Stream'),
      isFalse,
    );
    expect(
      RegExp(rule).hasMatch('/x/Wrapper/NetworkSnifferXapp/NetworkSniffer'),
      isFalse,
    );
  });
}
