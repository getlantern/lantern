import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart' show ffiErrorMessage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Localization.loadTranslations);

  group('ServiceUnavailableFailure', () {
    test('matches lantern-core\'s error for a service that needs repair', () {
      const error =
          'start service failed: lantern_service_unavailable '
          '(state=stopped start=disabled exit=1077/0 binary_missing=false): '
          'IPC not running';
      expect(ServiceUnavailableFailure.matches(error), isTrue);
      expect(
        ServiceUnavailableFailure(error).localizedErrorMessage,
        'lantern_service_unavailable_body'.i18n,
      );
    });

    test('does not match other connect errors', () {
      expect(
        ServiceUnavailableFailure.matches(
          'start service failed: IPC not running',
        ),
        isFalse,
      );
    });
  });

  group('ServiceRepairFailure', () {
    test('knows when the user declined the permission prompt', () {
      expect(
        ServiceRepairFailure('lantern_service_repair_cancelled').cancelled,
        isTrue,
      );
      expect(
        ServiceRepairFailure('lanternd install exited with code 1').cancelled,
        isFalse,
      );
    });
  });

  group('ffiErrorMessage', () {
    test('is null on success', () {
      expect(ffiErrorMessage('ok'), isNull);
      expect(ffiErrorMessage('true'), isNull);
      expect(ffiErrorMessage(''), isNull);
    });

    test('unwraps a JSON error', () {
      expect(ffiErrorMessage('{"error":"not_initialized"}'), 'not_initialized');
    });

    test('keeps a raw message', () {
      expect(
        ffiErrorMessage('start service failed: boom'),
        'start service failed: boom',
      );
    });
  });
}
