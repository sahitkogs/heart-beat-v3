import '../data/models/contact.dart';

/// Resolves the human-readable name for a peer pubkey, falling back
/// through (user-chosen displayName, last-broadcast claimedName, 6/6
/// truncated hex).
///
/// The 6/6 hex truncation matches MessageService._short and the existing
/// background_message_handler._short so labels stay consistent across
/// the app. Whitespace-only names are treated as missing.
String resolveName(String pubkeyHex, Contact? c) {
  final d = c?.displayName?.trim();
  if (d != null && d.isNotEmpty) return d;
  final cl = c?.claimedName?.trim();
  if (cl != null && cl.isNotEmpty) return cl;
  return shortPubkey(pubkeyHex);
}

/// 6/6 truncation: "abcdef…uvwxyz". Returns the input verbatim if it's
/// shorter than 16 chars (defensive — real pubkeys are always 64).
String shortPubkey(String hex) =>
    hex.length >= 16 ? '${hex.substring(0, 6)}…${hex.substring(hex.length - 6)}' : hex;
