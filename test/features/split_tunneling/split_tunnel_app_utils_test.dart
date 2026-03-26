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
