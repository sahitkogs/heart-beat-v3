import 'package:app_v3/data/models/contact.dart';
import 'package:app_v3/util/display_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Contact mk({String? display, String? claimed}) => Contact(
        pubkeyHex: '0' * 64,
        addedAt: DateTime.utc(2026, 5, 21),
        displayName: display,
        claimedName: claimed,
      );

  test('returns displayName when set', () {
    final n = resolveName('0' * 64, mk(display: 'Bob'));
    expect(n, 'Bob');
  });

  test('returns claimedName when displayName is null', () {
    final n = resolveName('0' * 64, mk(claimed: 'Bobby'));
    expect(n, 'Bobby');
  });

  test('returns truncated hex when both are null', () {
    final n = resolveName('a' * 64, mk());
    expect(n, 'aaaaaa…aaaaaa'); // 6/6 truncation
  });

  test('returns truncated hex when contact is null', () {
    final n = resolveName('b' * 64, null);
    expect(n, 'bbbbbb…bbbbbb');
  });

  test('displayName beats claimedName even if claimedName is longer', () {
    final n = resolveName('0' * 64, mk(display: 'X', claimed: 'YYY'));
    expect(n, 'X');
  });

  test('falls through to claimedName when displayName is whitespace', () {
    final n = resolveName('0' * 64, mk(display: '   ', claimed: 'Bobby'));
    expect(n, 'Bobby');
  });

  test('falls through to hex when both are whitespace', () {
    final n = resolveName('c' * 64, mk(display: ' ', claimed: '  '));
    expect(n, 'cccccc…cccccc');
  });

  test('shortPubkey returns input verbatim when too short', () {
    expect(shortPubkey('abc'), 'abc');
  });
}
