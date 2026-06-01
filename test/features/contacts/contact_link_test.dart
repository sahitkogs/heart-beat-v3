import 'package:flutter_test/flutter_test.dart';
import 'package:app_v3/features/contacts/contact_link.dart';

void main() {
  const hex = '116d49edaaee117f9f048fc1803b272412e3103dbd1f98971d5a77cb24e8c19b';

  test('toUri builds the https add-link with k and url-encoded n', () {
    final u = const ContactLink(hex, 'Al Ice').toUri();
    expect(u.scheme, 'https');
    expect(u.path, '/heart-beat-v3/add/');
    expect(u.queryParameters['k'], hex);
    expect(u.queryParameters['n'], 'Al Ice');
    expect(u.toString(), contains('n=Al%20Ice'));
  });

  test('toUri omits n when name is null/empty', () {
    expect(const ContactLink(hex, null).toUri().queryParameters.containsKey('n'), isFalse);
    expect(const ContactLink(hex, '').toUri().queryParameters.containsKey('n'), isFalse);
  });

  test('parse accepts the https landing URL', () {
    final c = ContactLink.parse(Uri.parse('https://sahitkogs.github.io/heart-beat-v3/add/?k=$hex&n=Al%20Ice'));
    expect(c, isNotNull);
    expect(c!.pubkeyHex, hex);
    expect(c.name, 'Al Ice');
  });

  test('parse accepts the heartbeat:// deep link', () {
    final c = ContactLink.parse(Uri.parse('heartbeat://add?k=$hex&n=Bob'));
    expect(c!.pubkeyHex, hex);
    expect(c.name, 'Bob');
  });

  test('parse rejects a non-64-hex k', () {
    expect(ContactLink.parse(Uri.parse('heartbeat://add?k=zzzz')), isNull);
    expect(ContactLink.parse(Uri.parse('heartbeat://add?n=Bob')), isNull); // no k
  });

  test('parse tolerates missing n', () {
    final c = ContactLink.parse(Uri.parse('heartbeat://add?k=$hex'));
    expect(c!.pubkeyHex, hex);
    expect(c.name, isNull);
  });
}
