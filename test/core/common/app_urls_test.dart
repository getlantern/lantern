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
      expect(
        AppUrls.appcastFor('nightly'),
        'https://update.getlantern.org/update/lantern/appcast.xml?channel=stable',
      );
    });

    test('uses the isolated staging feed for E2E fixtures', () {
      expect(
        AppUrls.appcastFor('beta', autoUpdateE2E: true),
        'https://update.staging.iantem.io/update/lantern/appcast.xml?channel=beta',
      );
    });
  });
}
