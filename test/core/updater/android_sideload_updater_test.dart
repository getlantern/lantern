import 'package:flutter/services.dart';
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
      });

      expect(update.url, 'https://downloads.example.com/lantern-installer.apk');
      expect(update.version, '9.1.0');
      expect(update.checksum, 'abc123');
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

  group('isAndroidSideloadStartupCheckDue', () {
    final now = DateTime.utc(2026, 5, 13, 12);

    test('runs when there is no usable previous startup check', () {
      expect(
        isAndroidSideloadStartupCheckDue(now: now, lastCheckAt: null),
        isTrue,
      );
      expect(
        isAndroidSideloadStartupCheckDue(now: now, lastCheckAt: 'not a date'),
        isTrue,
      );
    });

    test('throttles checks within the configured window', () {
      expect(
        isAndroidSideloadStartupCheckDue(
          now: now,
          lastCheckAt: now
              .subtract(const Duration(hours: 23))
              .toIso8601String(),
        ),
        isFalse,
      );
    });

    test('runs after the configured window elapses', () {
      expect(
        isAndroidSideloadStartupCheckDue(
          now: now,
          lastCheckAt: now
              .subtract(const Duration(hours: 25))
              .toIso8601String(),
        ),
        isTrue,
      );
    });
  });

  group('androidSideloadInstallFailureTelemetryEvent', () {
    test('classifies checksum and download failures', () {
      expect(
        androidSideloadInstallFailureTelemetryEvent(
          PlatformException(
            code: 'install_sideload_update',
            message: 'APK checksum mismatch',
          ),
        ),
        AndroidSideloadUpdateTelemetryEvent.checksumFailed,
      );
      expect(
        androidSideloadInstallFailureTelemetryEvent(
          PlatformException(
            code: 'install_sideload_update',
            message: 'APK download failed with HTTP 500',
          ),
        ),
        AndroidSideloadUpdateTelemetryEvent.downloadFailed,
      );
    });

    test('falls back to a generic install failure', () {
      expect(
        androidSideloadInstallFailureTelemetryEvent(Exception('bad package')),
        AndroidSideloadUpdateTelemetryEvent.installFailed,
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
