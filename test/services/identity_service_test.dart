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

    test('loadOrCreate throws FormatException when stored seed is not hex', () async {
      final storage = _MemoryStorage();
      // Pre-seed storage with a clearly-invalid value
      await storage.write('hb_v3_private_key', 'not-a-hex-string');
      final svc = IdentityService(KeyStorage(storage));
      await expectLater(svc.loadOrCreate(), throwsFormatException);
    });

    test('loadOrCreate throws when stored seed is wrong length', () async {
      final storage = _MemoryStorage();
      // 32 hex chars = 16 bytes; Ed25519 requires 32 bytes (64 hex)
      await storage.write('hb_v3_private_key', 'aa' * 16);
      final svc = IdentityService(KeyStorage(storage));
      await expectLater(svc.loadOrCreate(), throwsA(isA<ArgumentError>()));
    });
  });
}
