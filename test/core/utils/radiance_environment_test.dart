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
}
