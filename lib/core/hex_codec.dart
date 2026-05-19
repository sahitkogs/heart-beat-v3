/// Hex encoding / decoding helpers used by identity + contact code paths.
///
/// Lowercase only on encode; case-insensitive on decode (but we only ever
/// produce lowercase, so QR data stays canonical).

String bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

List<int> hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw const FormatException('hex length must be even');
  }
  final out = List<int>.filled(hex.length ~/ 2, 0);
  for (var i = 0; i < out.length; i++) {
    final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (byte == null) {
      throw FormatException('invalid hex at position ${i * 2}');
    }
    out[i] = byte;
  }
  return out;
}
