/// A scanned peer's identity. Phase 10.4.1 added displayName (user-chosen
/// nickname, winning) and claimedName (last broadcast by the peer).
class Contact {
  const Contact({
    required this.pubkeyHex,
    required this.addedAt,
    this.displayName,
    this.claimedName,
  });

  /// 64-char lowercase hex Ed25519 public key.
  final String pubkeyHex;

  /// When the user scanned this contact.
  final DateTime addedAt;

  /// Nickname the local user typed for this peer (in AddContactScreen, or
  /// edited later from contact details). Wins over claimedName.
  final String? displayName;

  /// Last name this peer broadcast in an inbound envelope's
  /// senderDisplayName field. Informational, not authenticated beyond
  /// the libsignal-session sender binding.
  final String? claimedName;

  Map<String, dynamic> toJson() => {
        'pubkey_hex': pubkeyHex,
        'added_at': addedAt.toUtc().toIso8601String(),
        if (displayName != null) 'display_name': displayName,
        if (claimedName != null) 'claimed_name': claimedName,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        pubkeyHex: json['pubkey_hex'] as String,
        addedAt: DateTime.parse(json['added_at'] as String),
        displayName: json['display_name'] as String?,
        claimedName: json['claimed_name'] as String?,
      );
}
