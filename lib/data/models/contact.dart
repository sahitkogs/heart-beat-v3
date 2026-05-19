/// A scanned peer's identity. Phase 10.1 stores just the pubkey + when added;
/// later phases will attach display name, relay info, last-seen, etc.
class Contact {
  const Contact({required this.pubkeyHex, required this.addedAt});

  /// 64-char lowercase hex Ed25519 public key.
  final String pubkeyHex;

  /// When the user scanned this contact.
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'pubkey_hex': pubkeyHex,
        'added_at': addedAt.toUtc().toIso8601String(),
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        pubkeyHex: json['pubkey_hex'] as String,
        addedAt: DateTime.parse(json['added_at'] as String),
      );
}
