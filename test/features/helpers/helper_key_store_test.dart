import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/helpers/helper_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates one 32-byte key and reuses it', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = HelperKeyStore();
    final a = await store.stateKey();
    final b = await store.stateKey();
    expect(a, hasLength(44)); // base64 of 32 bytes
    expect(b, a);
  });
}
