import 'package:app_v3/services/identity_service.dart';
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
  group('IdentityService', () {
    test('loadOrCreate generates new keypair when none stored', () async {
      final svc = IdentityService(KeyStorage(_MemoryStorage()));
      final identity = await svc.loadOrCreate();
      expect(identity.publicKeyHex.length, 64);
    });

    test('loadOrCreate returns same public key on subsequent calls', () async {
      final storage = _MemoryStorage();
      final svc = IdentityService(KeyStorage(storage));
      final first = await svc.loadOrCreate();
      final second = await svc.loadOrCreate();
      expect(second.publicKeyHex, first.publicKeyHex);
    });

    test('two different storages produce different public keys', () async {
      final a = await IdentityService(KeyStorage(_MemoryStorage())).loadOrCreate();
      final b = await IdentityService(KeyStorage(_MemoryStorage())).loadOrCreate();
      expect(a.publicKeyHex, isNot(equals(b.publicKeyHex)));
    });

    test('reset clears stored key', () async {
      final storage = _MemoryStorage();
      final svc = IdentityService(KeyStorage(storage));
      final first = await svc.loadOrCreate();
      await svc.reset();
      final second = await svc.loadOrCreate();
      expect(second.publicKeyHex, isNot(equals(first.publicKeyHex)));
    });
  });
}
