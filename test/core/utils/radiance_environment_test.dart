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

  test('staging build override wins over the local default', () async {
    final environment = await resolveRadianceEnvironment(
      buildOverride: 'staging',
      stagingMarkerExists: () async => false,
    );

    expect(environment, 'stage');
  });

  test('production build override wins over the local marker', () async {
    final environment = await resolveRadianceEnvironment(
      buildOverride: 'prod',
      stagingMarkerExists: () async => true,
    );

    expect(environment, 'prod');
  });

  test('local staging marker is used without a build override', () async {
    final environment = await resolveRadianceEnvironment(
      buildOverride: '',
      stagingMarkerExists: () async => true,
    );

    expect(environment, 'stage');
  });

  test('production is the default without an override or marker', () async {
    final environment = await resolveRadianceEnvironment(
      buildOverride: '',
      stagingMarkerExists: () async => false,
    );

    expect(environment, 'prod');
  });
}
