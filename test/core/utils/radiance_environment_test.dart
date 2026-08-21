import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/radiance_environment.dart';

void main() {
  test('normalizes supported Radiance environments', () {
    expect(normalizeRadianceEnvironment('prod'), 'prod');
    expect(normalizeRadianceEnvironment('staging'), 'stage');
    expect(normalizeRadianceEnvironment(' STAGING '), 'stage');
  });

  test('rejects unsupported Radiance environments', () {
    expect(() => normalizeRadianceEnvironment('stage'), throwsArgumentError);
  });

  test('build override wins and selects staging for release builds', () async {
    final environment = await resolveRadianceEnvironment(
      buildOverride: 'staging',
      releaseMode: true,
      stagingMarkerExists: () async => false,
    );

    expect(environment, 'stage');
  });

  test('release builds without an override stay on production', () async {
    final environment = await resolveRadianceEnvironment(
      buildOverride: '',
      releaseMode: true,
      stagingMarkerExists: () async => true,
    );

    expect(environment, 'prod');
  });

  test('development builds use the local staging marker', () async {
    final environment = await resolveRadianceEnvironment(
      buildOverride: '',
      releaseMode: false,
      stagingMarkerExists: () async => true,
    );

    expect(environment, 'stage');
  });
}
