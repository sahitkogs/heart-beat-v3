import 'package:app_v3/services/crypto_service.dart';
import 'package:app_v3/services/libsignal_crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CryptoService contract (LibsignalCryptoService)', () {
    late CryptoService alice;
    late CryptoService bob;

    setUp(() async {
      alice = LibsignalCryptoService();
      bob = LibsignalCryptoService();
      await alice.initialize();
      await bob.initialize();
    });

    test('Alice -> Bob round-trips a message after exchanging PreKey bundles',
        () async {
      // Alice fetches Bob's bundle (stamped with Bob's pubkey) and processes it.
      final bobBundle = (await bob.myPreKeyBundle()).copyWithOwner('bob-pubkey');
      await alice.processPeerPreKeyBundle(bobBundle);

      final plaintext = [0x48, 0x69, 0x21]; // "Hi!"
      final ciphertext = await alice.encrypt(
        peerPubkeyHex: 'bob-pubkey',
        plaintext: plaintext,
      );

      // For Bob to decrypt the very first message (PreKeySignalMessage type),
      // Bob does NOT need Alice's PreKey bundle in advance — the PreKey message
      // itself carries enough to bootstrap Bob's view of the session. Just
      // decrypt with Alice's address as the peer.
      final decoded = await bob.decrypt(
        peerPubkeyHex: 'alice-pubkey',
        ciphertext: ciphertext,
      );
      expect(decoded, plaintext);
    });

    test('Subsequent messages use the established session', () async {
      final bobBundle = (await bob.myPreKeyBundle()).copyWithOwner('bob-pubkey');
      await alice.processPeerPreKeyBundle(bobBundle);

      // Send + decrypt twice in a row to confirm the ratchet advances.
      final c1 = await alice.encrypt(peerPubkeyHex: 'bob-pubkey', plaintext: [1, 2, 3]);
      final p1 = await bob.decrypt(peerPubkeyHex: 'alice-pubkey', ciphertext: c1);
      expect(p1, [1, 2, 3]);

      final c2 = await alice.encrypt(peerPubkeyHex: 'bob-pubkey', plaintext: [4, 5, 6]);
      final p2 = await bob.decrypt(peerPubkeyHex: 'alice-pubkey', ciphertext: c2);
      expect(p2, [4, 5, 6]);

      // The two ciphertexts must differ (forward-secrecy ratchet at work).
      expect(c1, isNot(equals(c2)));
    });
  });
}
