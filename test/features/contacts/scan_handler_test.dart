import 'package:app_v3/features/contacts/scan_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanHandler.parse', () {
    test('accepts 64-char lowercase hex', () {
      final result = ScanHandler.parse('aa' * 32);
      expect(result.isValid, isTrue);
      expect(result.pubkeyHex, 'aa' * 32);
      expect(result.error, isNull);
    });

    test('rejects short hex', () {
      final result = ScanHandler.parse('aabbcc');
      expect(result.isValid, isFalse);
      expect(result.error, contains('expected 64'));
    });

    test('rejects non-hex characters', () {
      final result = ScanHandler.parse('zz' * 32);
      expect(result.isValid, isFalse);
      expect(result.error, contains('hex'));
    });

    test('normalizes uppercase input to lowercase', () {
      final result = ScanHandler.parse('AA' * 32);
      expect(result.isValid, isTrue);
      expect(result.pubkeyHex, 'aa' * 32);
    });

    test('trims surrounding whitespace', () {
      final result = ScanHandler.parse('  ${'aa' * 32}\n');
      expect(result.isValid, isTrue);
      expect(result.pubkeyHex, 'aa' * 32);
    });

    test('rejects empty input', () {
      final result = ScanHandler.parse('');
      expect(result.isValid, isFalse);
    });
  });
}
