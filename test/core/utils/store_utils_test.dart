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

  group('resolveStorePurchaseFlow', () {
    test('Play build normally routes purchases through store billing', () {
      expect(
        resolveStorePurchaseFlow(
          isStoreVersion: true,
          isAndroid: true,
          isExternalPaymentRegion: false,
        ),
        isTrue,
      );
    });

    test('Play build keeps the external path where Play is unenforced', () {
      expect(
        resolveStorePurchaseFlow(
          isStoreVersion: true,
          isAndroid: true,
          isExternalPaymentRegion: true,
        ),
        isFalse,
      );
    });

    test('iOS is unaffected by the Android-only exemption', () {
      expect(
        resolveStorePurchaseFlow(
          isStoreVersion: true,
          isAndroid: false,
          isExternalPaymentRegion: true,
        ),
        isTrue,
      );
    });

    test('non-store builds always use the external path', () {
      expect(
        resolveStorePurchaseFlow(
          isStoreVersion: false,
          isAndroid: true,
          isExternalPaymentRegion: false,
        ),
        isFalse,
      );
    });
  });

  group('resolvePlayBillingAvailability', () {
    test(
      'requires a known non-censored country for an Android store build',
      () {
        expect(
          resolvePlayBillingAvailability(
            isAndroid: true,
            isStoreVersion: true,
            isCountryKnown: true,
            isCensoredRegion: false,
          ),
          isTrue,
        );
        expect(
          resolvePlayBillingAvailability(
            isAndroid: true,
            isStoreVersion: true,
            isCountryKnown: false,
            isCensoredRegion: false,
          ),
          isFalse,
        );
        expect(
          resolvePlayBillingAvailability(
            isAndroid: true,
            isStoreVersion: true,
            isCountryKnown: true,
            isCensoredRegion: true,
          ),
          isFalse,
        );
      },
    );
  });
}
