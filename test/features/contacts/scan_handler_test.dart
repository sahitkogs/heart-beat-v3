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

  // Phase 10.3.1: the paste-pubkey flow in AddContactScreen reuses
  // ScanHandler.parse as its validator, so cases that are realistic
  // for hand-pasted (vs camera-scanned) input live here.
  group('ScanHandler.parse — paste-mode cases', () {
    test('accepts mixed-case hex and normalizes to lowercase', () {
      final result = ScanHandler.parse('AaBbCcDd' * 8);
      expect(result.isValid, isTrue);
      expect(result.pubkeyHex, 'aabbccdd' * 8);
    });

    test('rejects one-char-too-long input', () {
      final result = ScanHandler.parse('${'aa' * 32}a');
      expect(result.isValid, isFalse);
      expect(result.error, contains('expected 64'));
    });

    test('rejects pubkey with embedded space', () {
      // 64 chars total with an internal space — a realistic
      // copy/paste artifact from messengers that line-break long hex.
      final bad = '${'a' * 31} ${'a' * 32}';
      expect(bad.length, 64);
      final result = ScanHandler.parse(bad);
      expect(result.isValid, isFalse);
      expect(result.error, contains('hex'));
    });
  });
}
