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
}
