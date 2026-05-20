import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

import 'crypto_pre_key_bundle.dart';
import 'crypto_service.dart';

/// CryptoService implementation backed by libsignal_protocol_dart.
/// Uses the in-memory protocol store for Phase 10.2; persistence to
/// drift is a later phase concern.
class LibsignalCryptoService implements CryptoService {
  LibsignalCryptoService();

  late lsl.InMemorySignalProtocolStore _store;
  late int _registrationId;
  late int _deviceId;
  late int _ourPreKeyId;
  late int _ourSignedPreKeyId;
  // Cached at init: libsignal consumes a prekey once it's used to derive a
  // session, so loadPreKey() returns null on subsequent calls. The bundle
  // exposes only public keys, which are safe to keep returning.
  late CryptoPreKeyBundle _cachedBundle;

  @override
  Future<void> initialize() async {
    _registrationId = lsl.generateRegistrationId(false);
    _deviceId = 1;
    _ourPreKeyId = 1;
    _ourSignedPreKeyId = 1;

    final identityKeyPair = lsl.generateIdentityKeyPair();
    _store = lsl.InMemorySignalProtocolStore(identityKeyPair, _registrationId);

    final preKeys = lsl.generatePreKeys(_ourPreKeyId, 1);
    for (final pk in preKeys) {
      await _store.storePreKey(pk.id, pk);
    }

    final signedPreKey =
        lsl.generateSignedPreKey(identityKeyPair, _ourSignedPreKeyId);
    await _store.storeSignedPreKey(signedPreKey.id, signedPreKey);

    final preKey = preKeys.first;
    _cachedBundle = CryptoPreKeyBundle(
      ownerPubkeyHex: '',
      registrationId: _registrationId,
      deviceId: _deviceId,
      preKeyId: preKey.id,
      preKeyPublicHex: _hex(preKey.getKeyPair().publicKey.serialize()),
      signedPreKeyId: signedPreKey.id,
      signedPreKeyPublicHex:
          _hex(signedPreKey.getKeyPair().publicKey.serialize()),
      signedPreKeySignatureHex: _hex(signedPreKey.signature),
      identityKeyPublicHex: _hex(identityKeyPair.getPublicKey().serialize()),
    );
  }

  @override
  Future<CryptoPreKeyBundle> myPreKeyBundle() async => _cachedBundle;

  @override
  Future<void> processPeerPreKeyBundle(CryptoPreKeyBundle bundle) async {
    final peerAddress =
        lsl.SignalProtocolAddress(bundle.ownerPubkeyHex, bundle.deviceId);
    final pkb = lsl.PreKeyBundle(
      bundle.registrationId,
      bundle.deviceId,
      bundle.preKeyId,
      lsl.Curve.decodePoint(
          Uint8List.fromList(_unhex(bundle.preKeyPublicHex)), 0),
      bundle.signedPreKeyId,
      lsl.Curve.decodePoint(
          Uint8List.fromList(_unhex(bundle.signedPreKeyPublicHex)), 0),
      Uint8List.fromList(_unhex(bundle.signedPreKeySignatureHex)),
      lsl.IdentityKey(lsl.Curve.decodePoint(
          Uint8List.fromList(_unhex(bundle.identityKeyPublicHex)), 0)),
    );
    final builder =
        lsl.SessionBuilder.fromSignalStore(_store, peerAddress);
    await builder.processPreKeyBundle(pkb);
  }

  @override
  Future<List<int>> encrypt({
    required String peerPubkeyHex,
    required List<int> plaintext,
  }) async {
    final peerAddress = lsl.SignalProtocolAddress(peerPubkeyHex, _deviceId);
    final cipher = lsl.SessionCipher.fromStore(_store, peerAddress);
    final cipherMessage =
        await cipher.encrypt(Uint8List.fromList(plaintext));
    // Wire format: 1-byte type prefix + serialized message.
    return [cipherMessage.getType(), ...cipherMessage.serialize()];
  }

  @override
  Future<List<int>> decrypt({
    required String peerPubkeyHex,
    required List<int> ciphertext,
  }) async {
    if (ciphertext.isEmpty) {
      throw const FormatException('empty ciphertext');
    }
    final peerAddress = lsl.SignalProtocolAddress(peerPubkeyHex, _deviceId);
    final cipher = lsl.SessionCipher.fromStore(_store, peerAddress);
    final type = ciphertext.first;
    final payload = Uint8List.fromList(ciphertext.sublist(1));
    if (type == lsl.CiphertextMessage.prekeyType) {
      final msg = lsl.PreKeySignalMessage(payload);
      return cipher.decrypt(msg);
    }
    final msg = lsl.SignalMessage.fromSerialized(payload);
    return cipher.decryptFromSignal(msg);
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0')).join();

  List<int> _unhex(String hex) {
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }
}
