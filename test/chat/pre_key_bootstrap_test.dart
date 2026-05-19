import 'package:app_v3/chat/pre_key_bootstrap.dart';
import 'package:app_v3/services/crypto_pre_key_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

CryptoPreKeyBundle _sampleBundle() => CryptoPreKeyBundle(
      ownerPubkeyHex: 'aabb',
      registrationId: 7,
      deviceId: 1,
      preKeyId: 11,
      preKeyPublicHex: '01' * 32,
      signedPreKeyId: 12,
      signedPreKeyPublicHex: '02' * 32,
      signedPreKeySignatureHex: '03' * 32,
      identityKeyPublicHex: '04' * 32,
    );

void main() {
  group('EnvelopeWire', () {
    test('wrap + parse a PreKey bundle envelope', () {
      final wrapped = EnvelopeWire.wrapPreKeyBundle(_sampleBundle());
      expect(wrapped.first, EnvelopeTag.preKeyBundle);

      final parsed = EnvelopeWire.parse(wrapped);
      expect(parsed.isBundle, isTrue);
      expect(parsed.isMessage, isFalse);
      expect(parsed.bundle?.ownerPubkeyHex, 'aabb');
      expect(parsed.bundle?.registrationId, 7);
    });

    test('wrap + parse a message envelope', () {
      final ciphertext = [10, 20, 30, 40];
      final wrapped = EnvelopeWire.wrapMessage(ciphertext);
      expect(wrapped.first, EnvelopeTag.message);

      final parsed = EnvelopeWire.parse(wrapped);
      expect(parsed.isMessage, isTrue);
      expect(parsed.isBundle, isFalse);
      expect(parsed.ciphertext, ciphertext);
    });

    test('parse throws on empty envelope', () {
      expect(() => EnvelopeWire.parse(const []), throwsFormatException);
    });

    test('parse throws on unknown tag', () {
      expect(() => EnvelopeWire.parse([0xff, 1, 2]), throwsFormatException);
    });
  });
}
