import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_urls.dart';

void main() {
  group('AppUrls.appcastFor', () {
    test('uses lantern-cloud update service channels', () {
      expect(
        AppUrls.appcastFor('production'),
        'https://update.getlantern.org/update/lantern/appcast.xml?channel=stable',
      );
      expect(
        AppUrls.appcastFor('beta'),
        'https://update.getlantern.org/update/lantern/appcast.xml?channel=beta',
      );
      for (final entry in {
        TargetPlatform.windows: 'windows',
        TargetPlatform.macOS: 'macos',
      }.entries) {
        expect(
          AppUrls.appcastFor('nightly', platform: entry.key),
          'https://update.getlantern.org/update/lantern/appcast.xml?channel=nightly&platform=${entry.value}',
        );
      }
    });

    test('uses the current platform for nightly updates', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(
        AppUrls.appcastFor('nightly'),
        'https://update.getlantern.org/update/lantern/appcast.xml?channel=nightly&platform=windows',
      );
    });

    test('uses the isolated staging feed for E2E fixtures', () {
      for (final buildType in ['beta', 'nightly']) {
        expect(
          AppUrls.appcastFor(buildType, autoUpdateE2E: true),
          'https://update.staging.iantem.io/update/lantern/appcast.xml?channel=beta',
        );
      }
    });
  });
}
