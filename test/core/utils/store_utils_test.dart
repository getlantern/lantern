import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/store_utils.dart';

void main() {
  group('resolveAndroidStoreVersion', () {
    test('Play build remains a store build for an unknown installer', () {
      expect(
        resolveAndroidStoreVersion(isPlayStoreBuild: true, isSideLoaded: true),
        isTrue,
      );
    });

    test('Play build cannot be overridden to the non-store payment path', () {
      expect(
        resolveAndroidStoreVersion(
          isPlayStoreBuild: true,
          isSideLoaded: true,
          developerOverride: false,
        ),
        isTrue,
      );
    });

    test('non-Play builds still follow installer and developer state', () {
      expect(
        resolveAndroidStoreVersion(
          isPlayStoreBuild: false,
          isSideLoaded: false,
        ),
        isTrue,
      );
      expect(
        resolveAndroidStoreVersion(isPlayStoreBuild: false, isSideLoaded: true),
        isFalse,
      );
      expect(
        resolveAndroidStoreVersion(
          isPlayStoreBuild: false,
          isSideLoaded: true,
          developerOverride: true,
        ),
        isTrue,
      );
    });
  });

  group('resolvePlayBillingAvailability', () {
    test('is available on an Android store build outside censored regions', () {
      expect(
        resolvePlayBillingAvailability(
          isAndroid: true,
          isStoreVersion: true,
          isCensoredRegion: false,
        ),
        isTrue,
      );
    });

    test('is unavailable in a censored region', () {
      expect(
        resolvePlayBillingAvailability(
          isAndroid: true,
          isStoreVersion: true,
          isCensoredRegion: true,
        ),
        isFalse,
      );
    });

    test('is unavailable off Android or on non-store builds', () {
      expect(
        resolvePlayBillingAvailability(
          isAndroid: false,
          isStoreVersion: true,
          isCensoredRegion: false,
        ),
        isFalse,
      );
      expect(
        resolvePlayBillingAvailability(
          isAndroid: true,
          isStoreVersion: false,
          isCensoredRegion: false,
        ),
        isFalse,
      );
    });
  });
}
