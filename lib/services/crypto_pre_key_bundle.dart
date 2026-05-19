/// Public-only fields of a Signal PreKey bundle, exchanged via the relay
/// when two peers chat for the first time. Pure data — no methods beyond
/// JSON round-trip + a copyWith for the owner field.
class CryptoPreKeyBundle {
  const CryptoPreKeyBundle({
    required this.ownerPubkeyHex,
    required this.registrationId,
    required this.deviceId,
    required this.preKeyId,
    required this.preKeyPublicHex,
    required this.signedPreKeyId,
    required this.signedPreKeyPublicHex,
    required this.signedPreKeySignatureHex,
    required this.identityKeyPublicHex,
  });

  /// The Ed25519 public key (hex) of the user this bundle belongs to.
  /// Set at send time by the sender; CryptoService implementations may
  /// leave this empty in their generated bundle and rely on the caller
  /// to stamp it via [copyWithOwner].
  final String ownerPubkeyHex;
  final int registrationId;
  final int deviceId;
  final int preKeyId;
  final String preKeyPublicHex;
  final int signedPreKeyId;
  final String signedPreKeyPublicHex;
  final String signedPreKeySignatureHex;
  final String identityKeyPublicHex;

  CryptoPreKeyBundle copyWithOwner(String ownerPubkeyHex) =>
      CryptoPreKeyBundle(
        ownerPubkeyHex: ownerPubkeyHex,
        registrationId: registrationId,
        deviceId: deviceId,
        preKeyId: preKeyId,
        preKeyPublicHex: preKeyPublicHex,
        signedPreKeyId: signedPreKeyId,
        signedPreKeyPublicHex: signedPreKeyPublicHex,
        signedPreKeySignatureHex: signedPreKeySignatureHex,
        identityKeyPublicHex: identityKeyPublicHex,
      );

  Map<String, dynamic> toJson() => {
        'owner_pubkey_hex': ownerPubkeyHex,
        'registration_id': registrationId,
        'device_id': deviceId,
        'pre_key_id': preKeyId,
        'pre_key_public_hex': preKeyPublicHex,
        'signed_pre_key_id': signedPreKeyId,
        'signed_pre_key_public_hex': signedPreKeyPublicHex,
        'signed_pre_key_signature_hex': signedPreKeySignatureHex,
        'identity_key_public_hex': identityKeyPublicHex,
      };

  factory CryptoPreKeyBundle.fromJson(Map<String, dynamic> j) =>
      CryptoPreKeyBundle(
        ownerPubkeyHex: j['owner_pubkey_hex'] as String,
        registrationId: j['registration_id'] as int,
        deviceId: j['device_id'] as int,
        preKeyId: j['pre_key_id'] as int,
        preKeyPublicHex: j['pre_key_public_hex'] as String,
        signedPreKeyId: j['signed_pre_key_id'] as int,
        signedPreKeyPublicHex: j['signed_pre_key_public_hex'] as String,
        signedPreKeySignatureHex: j['signed_pre_key_signature_hex'] as String,
        identityKeyPublicHex: j['identity_key_public_hex'] as String,
      );
}
