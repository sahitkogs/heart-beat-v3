import 'package:cryptography/cryptography.dart';

import '../core/hex_codec.dart';
import 'key_storage.dart';

/// The user's public identity. Never carries the private seed.
class Identity {
  const Identity({required this.publicKeyHex});
  final String publicKeyHex;
}

/// Generates the user's Ed25519 keypair on first launch and reloads it
/// thereafter from secure storage. Returns only the public key in [Identity];
/// the seed stays inside [KeyStorage] and is reached only by [SigningService].
class IdentityService {
  IdentityService(this._keys);

  final KeyStorage _keys;
  final _algo = Ed25519();

  Future<Identity> loadOrCreate() async {
    final existing = await _keys.readPrivateKey();
    if (existing != null) {
      final seed = hexToBytes(existing);
      final pair = await _algo.newKeyPairFromSeed(seed);
      final pub = await pair.extractPublicKey();
      return Identity(publicKeyHex: bytesToHex(pub.bytes));
    }
    final pair = await _algo.newKeyPair();
    final seedBytes = await pair.extractPrivateKeyBytes();
    final pub = await pair.extractPublicKey();
    final seedHex = bytesToHex(seedBytes);
    await _keys.writePrivateKey(seedHex);
    return Identity(publicKeyHex: bytesToHex(pub.bytes));
  }

  Future<void> reset() => _keys.deletePrivateKey();
}
