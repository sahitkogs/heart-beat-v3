import 'package:app_v3/services/key_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements SecureKeyValueStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}

void main() {
  group('KeyStorage', () {
    test('returns null when no private key stored', () async {
      final storage = KeyStorage(_MemoryStorage());
      expect(await storage.readPrivateKey(), isNull);
    });

    test('writes and reads back the private key hex', () async {
      final storage = KeyStorage(_MemoryStorage());
      await storage.writePrivateKey('aabb');
      expect(await storage.readPrivateKey(), 'aabb');
    });

    test('delete removes the key', () async {
      final storage = KeyStorage(_MemoryStorage());
      await storage.writePrivateKey('aabb');
      await storage.deletePrivateKey();
      expect(await storage.readPrivateKey(), isNull);
    });
  });
}
