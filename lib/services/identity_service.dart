import 'package:cryptography/cryptography.dart';

import '../core/hex_codec.dart';
import 'key_storage.dart';

/// The user's identity in v3 — an Ed25519 keypair.
class Identity {
  const Identity({required this.publicKeyHex, required this.privateKeyHex});

  /// Lowercase hex of the 32-byte public key. 64 chars.
  final String publicKeyHex;

  /// Lowercase hex of the 32-byte Ed25519 seed (private material). 64 chars.
  final String privateKeyHex;
}

/// Generates the user's Ed25519 keypair on first launch and reloads it
/// thereafter from secure storage.
class IdentityService {
  IdentityService(this._keys);

  final KeyStorage _keys;
  final _algo = Ed25519();

  Future<Identity> loadOrCreate() async {
    final existing = await _keys.readPrivateKey();
    if (existing != null) {
      return _reconstructFromSeedHex(existing);
    }
    final keyPair = await _algo.newKeyPair();
    final seedBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final identity = Identity(
      publicKeyHex: bytesToHex(publicKey.bytes),
      privateKeyHex: bytesToHex(seedBytes),
    );
    await _keys.writePrivateKey(identity.privateKeyHex);
    return identity;
  }

  Future<void> reset() => _keys.deletePrivateKey();

  Future<Identity> _reconstructFromSeedHex(String seedHex) async {
    final seedBytes = hexToBytes(seedHex);
    final keyPair = await _algo.newKeyPairFromSeed(seedBytes);
    final publicKey = await keyPair.extractPublicKey();
    return Identity(
      publicKeyHex: bytesToHex(publicKey.bytes),
      privateKeyHex: seedHex,
    );
  }
}
