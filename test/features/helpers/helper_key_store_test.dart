import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/helpers/helper_key_store.dart';

class _Storage implements FlutterSecureStorage {
  _Storage({this.value, this.readFails = false});
  String? value;
  final bool readFails;
  int writes = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (readFails) throw Exception('the keyring is locked');
    return value;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    this.value = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  test('mints a key only when the read finds nothing', () async {
    final storage = _Storage();
    final key = await HelperKeyStore(storage).stateKey();
    expect(key, hasLength(44));
    expect(storage.writes, 1);
    expect(storage.value, key);
  });

  test('a failed read throws and never mints or writes', () async {
    final storage = _Storage(value: 'k' * 44, readFails: true);
    await expectLater(HelperKeyStore(storage).stateKey(), throwsException);
    expect(storage.writes, 0);
    expect(storage.value, 'k' * 44);
  });

  test('a malformed stored value is replaced with a new key', () async {
    for (final bad in ['short', '!' * 44]) {
      final storage = _Storage(value: bad);
      final key = await HelperKeyStore(storage).stateKey();
      expect(key, hasLength(44));
      expect(key, isNot(bad));
      expect(storage.writes, 1);
      expect(storage.value, key);
    }
  });

  test('a valid stored key is reused without a write', () async {
    final good = base64.encode(List.filled(32, 7));
    final storage = _Storage(value: good);
    expect(await HelperKeyStore(storage).stateKey(), good);
    expect(storage.writes, 0);
  });
}
