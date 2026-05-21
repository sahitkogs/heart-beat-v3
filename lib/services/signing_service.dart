import 'package:cryptography/cryptography.dart';

import '../core/hex_codec.dart';
import 'key_storage.dart';

/// Holds the user's Ed25519 seed internally and exposes a narrow API for
/// signing only. Callers never see the seed.
class SigningService {
  SigningService(this._keys);

  final KeyStorage _keys;
  final _algo = Ed25519();

  static final _verifyAlgo = Ed25519();

  static Future<bool> verify({
    required String publicKeyHex,
    required List<int> message,
    required List<int> signature,
  }) async {
    try {
      final pubKey = SimplePublicKey(hexToBytes(publicKeyHex), type: KeyPairType.ed25519);
      final sig = Signature(signature, publicKey: pubKey);
      return await _verifyAlgo.verify(message, signature: sig);
    } catch (_) {
      return false;
    }
  }

  Future<List<int>> sign(List<int> bytes) async {
    final seedHex = await _keys.readPrivateKey();
    if (seedHex == null) {
      throw StateError('SigningService: no private key in storage');
    }
    final pair = await _algo.newKeyPairFromSeed(hexToBytes(seedHex));
    final sig = await _algo.sign(bytes, keyPair: pair);
    return sig.bytes;
  }

  Future<String> publicKeyHex() async {
    final seedHex = await _keys.readPrivateKey();
    if (seedHex == null) {
      throw StateError('SigningService: no private key in storage');
    }
    final pair = await _algo.newKeyPairFromSeed(hexToBytes(seedHex));
    final pub = await pair.extractPublicKey();
    return bytesToHex(pub.bytes);
  }
}
