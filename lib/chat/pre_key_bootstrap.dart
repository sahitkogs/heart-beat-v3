import 'dart:convert';

import '../services/crypto_pre_key_bundle.dart';

/// Wire-format tag byte at the start of each relay envelope.
class EnvelopeTag {
  static const int preKeyBundle = 0x01;
  static const int message = 0x02;
}

/// Result of parsing an envelope. Exactly one of [bundle] or [ciphertext]
/// will be non-null on success.
class ParsedEnvelope {
  ParsedEnvelope._({this.bundle, this.ciphertext});

  factory ParsedEnvelope.preKeyBundle(CryptoPreKeyBundle b) =>
      ParsedEnvelope._(bundle: b);

  factory ParsedEnvelope.message(List<int> c) =>
      ParsedEnvelope._(ciphertext: c);

  final CryptoPreKeyBundle? bundle;
  final List<int>? ciphertext;

  bool get isBundle => bundle != null;
  bool get isMessage => ciphertext != null;
}

/// Builders + parsers for the tagged envelope wire format used between
/// peers via the relay's `deliver` frame.
class EnvelopeWire {
  EnvelopeWire._();

  /// Wrap a [CryptoPreKeyBundle] for transmission. Tag byte 0x01 + JSON bytes.
  static List<int> wrapPreKeyBundle(CryptoPreKeyBundle bundle) {
    final json = utf8.encode(jsonEncode(bundle.toJson()));
    return [EnvelopeTag.preKeyBundle, ...json];
  }

  /// Wrap an encrypted message payload for transmission. Tag byte 0x02 + ciphertext.
  static List<int> wrapMessage(List<int> ciphertext) {
    return [EnvelopeTag.message, ...ciphertext];
  }

  /// Parse a received envelope into a [ParsedEnvelope].
  /// Throws [FormatException] on empty input or an unknown tag.
  static ParsedEnvelope parse(List<int> envelope) {
    if (envelope.isEmpty) {
      throw const FormatException('empty envelope');
    }
    final tag = envelope.first;
    final payload = envelope.sublist(1);
    if (tag == EnvelopeTag.preKeyBundle) {
      final json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      return ParsedEnvelope.preKeyBundle(CryptoPreKeyBundle.fromJson(json));
    } else if (tag == EnvelopeTag.message) {
      return ParsedEnvelope.message(payload);
    }
    throw FormatException('unknown envelope tag $tag');
  }
}
