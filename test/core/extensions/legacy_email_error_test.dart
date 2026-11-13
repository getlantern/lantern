import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/error.dart';

void main() {
  for (final prefix in [
    '',
    'ipc: status 500: ',
    'Error completing legacy email binding: ',
  ]) {
    test('preserves binding validation errors with prefix: $prefix', () {
      final error = PlatformException(
        code: 'error',
        message:
            '${prefix}legacy email binding: HTTP 400: received bad response: '
            'invalid or expired verification code',
      );

      expect(
        error.localizedDescription,
        'invalid or expired verification code',
      );
    });
  }
}
