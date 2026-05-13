import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/updater/android_sideload_updater.dart';

void main() {
  group('androidSideloadUpdateRequestBody', () {
    test('builds the update contract expected by lantern-cloud', () {
      final body = androidSideloadUpdateRequestBody(
        appVersion: '9.0.28',
        buildNumber: '95',
        osVersion: '15',
        supportedAbis: const ['arm64-v8a', 'armeabi-v7a'],
        buildType: 'production',
      );

      expect(body['version'], 1);
      expect(body['app_version'], '9.0.28');
      expect(body['os_version'], '15');
      expect(body['checksum'], '');
      expect(body['tags'], containsPair('installer_source', 'sideload'));
      expect(body['tags'], containsPair('os', 'android'));
      expect(body['tags'], containsPair('arch', 'arm64'));
      expect(body['tags'], containsPair('channel', 'stable'));
      expect(body['tags'], containsPair('build_number', '95'));
    });
  });

  group('androidUpdateArchForAbis', () {
    test('prefers arm64 when present', () {
      expect(androidUpdateArchForAbis(['arm64-v8a', 'armeabi-v7a']), 'arm64');
    });

    test('falls back to arm for shared APK indexing', () {
      expect(androidUpdateArchForAbis(['x86_64']), 'arm');
      expect(androidUpdateArchForAbis([]), 'arm');
    });
  });

  group('androidUpdateChannelForBuildType', () {
    test('maps build types to supported update channels', () {
      expect(androidUpdateChannelForBuildType('production'), 'stable');
      expect(androidUpdateChannelForBuildType('beta'), 'beta');
      expect(androidUpdateChannelForBuildType('nightly'), 'nightly');
      expect(androidUpdateChannelForBuildType('internal'), 'nightly');
    });
  });

  group('AndroidSideloadUpdate.fromJson', () {
    test('parses full APK responses', () {
      final update = AndroidSideloadUpdate.fromJson({
        'url': 'https://downloads.example.com/lantern-installer.apk',
        'patch_type': '',
        'version': '9.1.0',
        'checksum': 'abc123',
        'signature': 'def456',
      });

      expect(update.url, 'https://downloads.example.com/lantern-installer.apk');
      expect(update.version, '9.1.0');
      expect(update.checksum, 'abc123');
      expect(update.signature, 'def456');
    });

    test('rejects patch responses and non-https URLs', () {
      expect(
        () => AndroidSideloadUpdate.fromJson({
          'url': 'https://downloads.example.com/lantern-installer.apk',
          'patch_type': 'bsdiff',
          'version': '9.1.0',
        }),
        throwsFormatException,
      );
      expect(
        () => AndroidSideloadUpdate.fromJson({
          'url': 'http://downloads.example.com/lantern-installer.apk',
          'patch_type': '',
          'version': '9.1.0',
          'checksum': 'abc123',
        }),
        throwsFormatException,
      );
    });

    test('requires a checksum for native APK verification', () {
      expect(
        () => AndroidSideloadUpdate.fromJson({
          'url': 'https://downloads.example.com/lantern-installer.apk',
          'patch_type': '',
          'version': '9.1.0',
        }),
        throwsFormatException,
      );
    });
  });

  group('isAndroidUpdateVersionNewer', () {
    test('compares stable and prerelease versions', () {
      expect(isAndroidUpdateVersionNewer('v9.1.0', '9.0.28'), isTrue);
      expect(isAndroidUpdateVersionNewer('9.1.0', '9.1.0'), isFalse);
      expect(
        isAndroidUpdateVersionNewer('9.1.0-beta.2', '9.1.0-beta.1'),
        isTrue,
      );
      expect(isAndroidUpdateVersionNewer('9.1.0-beta.1', '9.1.0'), isFalse);
      expect(isAndroidUpdateVersionNewer('9.1.0', '9.1.0-beta.1'), isTrue);
    });
  });
}
