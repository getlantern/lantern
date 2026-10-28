import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the key that seals lantern-core's helper state (invite secrets, the
/// device key and helper names) in the OS keystore: Keychain, the Android
/// Keystore, Windows Credential Manager or libsecret. The key never leaves
/// the device and is never logged.
class HelperKeyStore {
  HelperKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // The macOS app is not sandboxed; the file-based keychain needs no
            // access-group entitlement.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;
  static const _name = 'lantern_helper_state_key_v1';

  /// Returns the key, creating it on first use. Throws when the keystore is
  /// unavailable, as on Linux without a running keyring.
  Future<String> stateKey() async {
    final existing = await _storage.read(key: _name);
    if (existing != null && existing.length == 44) return existing;
    final rnd = Random.secure();
    final key = base64.encode(
      Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256))),
    );
    await _storage.write(key: _name, value: key);
    return key;
  }
}
