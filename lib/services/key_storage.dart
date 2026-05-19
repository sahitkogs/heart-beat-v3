import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal interface wrapping a string KV store so tests can substitute
/// an in-memory fake. Production uses [FlutterSecureStorage], which is
/// backed by Android Keystore.
abstract class SecureKeyValueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureStorageAdapter implements SecureKeyValueStorage {
  _FlutterSecureStorageAdapter()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores and retrieves the Ed25519 private key for the user's identity.
/// The private key is held as a hex string under the key `hb_v3_private_key`.
class KeyStorage {
  KeyStorage([SecureKeyValueStorage? storage])
      : _storage = storage ?? _FlutterSecureStorageAdapter();

  static const String _privateKeyKey = 'hb_v3_private_key';

  final SecureKeyValueStorage _storage;

  Future<String?> readPrivateKey() => _storage.read(_privateKeyKey);

  Future<void> writePrivateKey(String hex) =>
      _storage.write(_privateKeyKey, hex);

  Future<void> deletePrivateKey() => _storage.delete(_privateKeyKey);
}
