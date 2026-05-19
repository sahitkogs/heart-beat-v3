import 'package:cryptography/cryptography.dart';

import '../core/hex_codec.dart';
import 'key_storage.dart';

/// Holds the user's Ed25519 seed internally and exposes a narrow API for
/// signing only. Callers never see the seed.
class SigningService {
  SigningService(this._keys);

  final KeyStorage _keys;
  final _algo = Ed25519();

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
