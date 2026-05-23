import 'crypto_pre_key_bundle.dart';

/// Abstraction over the underlying Signal-protocol binding so the rest of
/// the app depends on this interface, not on a particular implementation.
/// Concrete implementations: LibsignalCryptoService (Task 8); future FFI
/// or fallback implementations swap in here.
abstract class CryptoService {
  /// Bootstrap on first launch — initialize the local Signal store,
  /// generate our PreKey + signed PreKey, persist registration ID.
  /// Idempotent on a per-instance basis (callers should construct once
  /// per app lifetime).
  Future<void> initialize();

  /// Produce our own PreKey bundle so it can be shared with a new peer.
  /// Implementations may leave [CryptoPreKeyBundle.ownerPubkeyHex] empty;
  /// the caller stamps it via [CryptoPreKeyBundle.copyWithOwner] before
  /// sending.
  Future<CryptoPreKeyBundle> myPreKeyBundle();

  /// Save a peer's PreKey bundle locally so we can encrypt messages to them.
  Future<void> processPeerPreKeyBundle(CryptoPreKeyBundle bundle);

  /// Encrypt a plaintext message for a specific peer (by their Ed25519
  /// public-key hex). Returns the ciphertext bytes that will travel via
  /// the relay.
  Future<List<int>> encrypt({
    required String peerPubkeyHex,
    required List<int> plaintext,
  });

  /// Decrypt an incoming ciphertext from a peer.
  Future<List<int>> decrypt({
    required String peerPubkeyHex,
    required List<int> ciphertext,
  });

  /// Drop all crypto state for a peer (Signal sessions, ratchet keys, cached
  /// identities) so a subsequent [processPeerPreKeyBundle] establishes a fresh
  /// X3DH session. Used when the user deletes a contact or the peer rotates
  /// their identity (e.g. by reinstalling).
  Future<void> forgetPeer(String peerPubkeyHex);
}
