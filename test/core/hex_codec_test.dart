import 'package:app_v3/core/hex_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hex codec', () {
    test('encodes bytes to lowercase hex', () {
      expect(bytesToHex([0xde, 0xad, 0xbe, 0xef]), 'deadbeef');
    });

    test('decodes lowercase hex to bytes', () {
      expect(hexToBytes('deadbeef'), [0xde, 0xad, 0xbe, 0xef]);
    });

    test('round-trips arbitrary bytes', () {
      final original = List<int>.generate(32, (i) => i * 7 & 0xff);
      expect(hexToBytes(bytesToHex(original)), original);
    });

    test('throws on odd-length hex', () {
      expect(() => hexToBytes('abc'), throwsFormatException);
    });

    test('throws on non-hex characters', () {
      expect(() => hexToBytes('zzzz'), throwsFormatException);
    });
  });
}
