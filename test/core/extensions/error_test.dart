import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/extensions/error.dart';
import 'package:lantern/core/localization/i18n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Localization.loadTranslations);

  for (final message in [
    'server "Home" already exists',
    'server with tag "Home" already exists',
    r'server with tag "My \"Home\" server" already exists',
  ]) {
    for (final prefix in [
      '',
      'ipc: status 500: ',
      'Error adding server based on URLs: ipc: status 500: ',
    ]) {
      test('preserves duplicate-server message: $prefix$message', () {
        final error = PlatformException(
          code: 'error',
          message: '$prefix$message',
        );

        expect(error.localizedDescription, message);
      });
    }
  }

  test('does not classify unrelated errors as duplicate servers', () {
    final error = PlatformException(
      code: 'error',
      message: 'server with tag "Home" not found',
    );

    expect(error.localizedDescription, 'an_error_occurred'.i18n);
  });
}
