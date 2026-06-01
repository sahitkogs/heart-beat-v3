/// The add-contact link shared via QR-less channels (WhatsApp, etc.) and
/// consumed by the heartbeat://add deep link. Carries the pubkey (k) and an
/// optional display name (n). This is the single encode/parse point.
class ContactLink {
  const ContactLink(this.pubkeyHex, this.name);
  final String pubkeyHex;
  final String? name;

  static final Uri _base = Uri.parse('https://sahitkogs.github.io/heart-beat-v3/add/');
  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// The shareable https URL.
  /// We encode spaces as %20 (not +) by using [Uri.encodeComponent] which
  /// percent-encodes all special characters including spaces, then build
  /// the full URI string directly.
  Uri toUri() {
    final k = Uri.encodeComponent(pubkeyHex);
    final suffix = (name != null && name!.isNotEmpty)
        ? '&n=${Uri.encodeComponent(name!)}'
        : '';
    return Uri.parse('${_base}?k=$k$suffix');
  }

  /// Parse either the https landing URL or the heartbeat://add deep link.
  /// Returns null unless `k` is a valid 64-char lowercase hex pubkey.
  static ContactLink? parse(Uri uri) {
    final k = uri.queryParameters['k']?.trim().toLowerCase();
    if (k == null || !_hex64.hasMatch(k)) return null;
    final n = uri.queryParameters['n'];
    return ContactLink(k, (n != null && n.isNotEmpty) ? n : null);
  }
}
