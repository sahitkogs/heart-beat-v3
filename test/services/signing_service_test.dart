import 'dart:convert';

import 'package:app_v3/core/hex_codec.dart';
import 'package:app_v3/services/identity_service.dart';
import 'package:app_v3/services/key_storage.dart';
import 'package:app_v3/services/signing_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements SecureKeyValueStorage {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
}

void main() {
  test('sign then verify with stored Ed25519 key succeeds', () async {
    final ks = KeyStorage(_MemoryStorage());
    final id = IdentityService(ks);
    await id.loadOrCreate();

    final signer = SigningService(ks);
    final pubHex = await signer.publicKeyHex();
    final sig = await signer.sign([1, 2, 3, 4]);

    final pubBytes = hexToBytes(pubHex);
    final algo = Ed25519();
    final ok = await algo.verify(
      [1, 2, 3, 4],
      signature: Signature(
        sig,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
      ),
    );
    expect(ok, isTrue);
  });

  test('sign throws when no key has been generated yet', () async {
    final signer = SigningService(KeyStorage(_MemoryStorage()));
    expect(() => signer.sign([1, 2, 3]), throwsStateError);
  });

  group('verify (static)', () {
    test('accepts a valid signature', () async {
      final keys = KeyStorage(_MemoryStorage());
      final svc = SigningService(keys);
      await keys.writePrivateKey('a' * 64); // 32-byte hex seed
      final pubHex = await svc.publicKeyHex();
      final msg = utf8.encode('hello group');
      final sig = await svc.sign(msg);
      final ok = await SigningService.verify(
        publicKeyHex: pubHex,
        message: msg,
        signature: sig,
      );
      expect(ok, isTrue);
    });

    test('rejects a tampered signature', () async {
      final keys = KeyStorage(_MemoryStorage());
      final svc = SigningService(keys);
      await keys.writePrivateKey('b' * 64);
      final pubHex = await svc.publicKeyHex();
      final sig = await svc.sign(utf8.encode('original'));
      final ok = await SigningService.verify(
        publicKeyHex: pubHex,
        message: utf8.encode('tampered'),
        signature: sig,
      );
      expect(ok, isFalse);
    });

    test('rejects under wrong pubkey', () async {
      final keys = KeyStorage(_MemoryStorage());
      final svc = SigningService(keys);
      await keys.writePrivateKey('c' * 64);
      final sig = await svc.sign(utf8.encode('msg'));
      final ok = await SigningService.verify(
        publicKeyHex: 'd' * 64,
        message: utf8.encode('msg'),
        signature: sig,
      );
      expect(ok, isFalse);
    });
  });
}
