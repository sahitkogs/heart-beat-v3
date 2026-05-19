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
}
