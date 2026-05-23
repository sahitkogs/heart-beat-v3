import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

import '../data/app_database.dart';
import 'crypto_pre_key_bundle.dart';
import 'crypto_service.dart';
import 'signal_store/drift_signal_protocol_store.dart';

/// `CryptoService` implementation backed by `libsignal_protocol_dart` with a
/// persistent drift-backed `SignalProtocolStore`. Identity and signed-prekey
/// material survive app restart; the FCM background isolate (T7) shares the
/// same on-disk store.
class LibsignalCryptoService implements CryptoService {
  LibsignalCryptoService(this._db);

  final AppDatabase _db;

  late final DriftSignalProtocolStore _store = DriftSignalProtocolStore(_db);

  // Stable across the life of one install — known limitation: single fixed
  // prekey id, multi-peer rotation deferred to 10.4/10.5.
  static const int _deviceId = 1;
  static const int _ourPreKeyId = 1;
  static const int _ourSignedPreKeyId = 1;

  // Cached at init: libsignal consumes a prekey when it builds a session
  // (removePreKey gets called), so loading it on demand for the bundle would
  // return null after the first peer pairs. The bundle is public-key info
  // only, so caching is safe.
  late CryptoPreKeyBundle _cachedBundle;

  @override
  Future<void> initialize() async {
    if (await _store.identityKeyStore.hasLocalIdentity()) {
      await _loadExistingIdentity();
    } else {
      await _bootstrapFreshIdentity();
    }
  }

  Future<void> _bootstrapFreshIdentity() async {
    final identityKeyPair = lsl.generateIdentityKeyPair();
    final registrationId = lsl.generateRegistrationId(false);
    await _store.identityKeyStore.saveLocalIdentity(
      identityKeyPair: identityKeyPair,
      registrationId: registrationId,
      deviceId: _deviceId,
    );

    final preKey = lsl.generatePreKeys(_ourPreKeyId, 1).single;
    await _store.storePreKey(preKey.id, preKey);

    final signedPreKey =
        lsl.generateSignedPreKey(identityKeyPair, _ourSignedPreKeyId);
    await _store.storeSignedPreKey(signedPreKey.id, signedPreKey);

    _cachedBundle = _buildBundle(
      identityKeyPair: identityKeyPair,
      registrationId: registrationId,
      preKey: preKey,
      signedPreKey: signedPreKey,
    );
  }

  Future<void> _loadExistingIdentity() async {
    final identityKeyPair = await _store.getIdentityKeyPair();
    final registrationId = await _store.getLocalRegistrationId();

    // Load the prekey if it's still alive; otherwise re-generate with the
    // same id. Peer apps that cached the OLD bundle will see decryption
    // failures until they refresh — same limitation as the in-memory build,
    // just better-defined now.
    final lsl.PreKeyRecord preKey;
    if (await _store.containsPreKey(_ourPreKeyId)) {
      preKey = await _store.loadPreKey(_ourPreKeyId);
    } else {
      preKey = lsl.generatePreKeys(_ourPreKeyId, 1).single;
      await _store.storePreKey(preKey.id, preKey);
    }

    final signedPreKey = await _store.loadSignedPreKey(_ourSignedPreKeyId);

    _cachedBundle = _buildBundle(
      identityKeyPair: identityKeyPair,
      registrationId: registrationId,
      preKey: preKey,
      signedPreKey: signedPreKey,
    );
  }

  CryptoPreKeyBundle _buildBundle({
    required lsl.IdentityKeyPair identityKeyPair,
    required int registrationId,
    required lsl.PreKeyRecord preKey,
    required lsl.SignedPreKeyRecord signedPreKey,
  }) {
    return CryptoPreKeyBundle(
      ownerPubkeyHex: '',
      registrationId: registrationId,
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

  @override
  Future<void> forgetPeer(String peerPubkeyHex) async {
    await _store.deleteAllSessions(peerPubkeyHex);
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
