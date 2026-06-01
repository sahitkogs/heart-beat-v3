import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/chat/message_service.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/data/contacts_repository.dart';
import 'package:app_v3/data/group_members_dao.dart';
import 'package:app_v3/data/group_ops_log_dao.dart';
import 'package:app_v3/data/models/contact.dart' as model;
import 'package:app_v3/data/outbox_dao.dart';
import 'package:app_v3/data/peer_bundle_state_dao.dart';
import 'package:app_v3/data/profile_dao.dart';
import 'package:app_v3/features/chat/message_service_provider.dart';
import 'package:app_v3/features/contacts/contacts_provider.dart';
import 'package:app_v3/features/presence/presence_provider.dart';
import 'package:app_v3/relay/relay_client.dart';
import 'package:app_v3/relay/relay_frames.dart';
import 'package:app_v3/services/crypto_pre_key_bundle.dart';
import 'package:app_v3/services/crypto_service.dart';
import 'package:app_v3/services/identity_service.dart';
import 'package:app_v3/services/key_storage.dart';
import 'package:app_v3/services/presence_client.dart';
import 'package:app_v3/services/signing_service.dart';

void main() {
  test('detects offline/stale->online transitions', () {
    final prev = <String, PresenceInfo>{
      'aa': PresenceInfo(online: false),
      'bb': PresenceInfo(online: true),
    };
    final next = <String, PresenceInfo>{
      'aa': PresenceInfo(online: true), // transitioned UP
      'bb': PresenceInfo(online: true), // stayed online
      'cc': PresenceInfo(online: true), // newly seen online
    };
    final ups = newlyOnline(prev, next);
    expect(ups, containsAll(<String>['aa', 'cc']));
    expect(ups.contains('bb'), isFalse);
  });

  test('no transitions when nothing came online', () {
    final prev = <String, PresenceInfo>{'aa': PresenceInfo(online: true)};
    final next = <String, PresenceInfo>{'aa': PresenceInfo(online: true)};
    expect(newlyOnline(prev, next), isEmpty);
  });

  // Fix 5 (B/C review) — end-to-end pollOnce → flush.
  //
  // Wires a ProviderContainer so a real pollOnce() runs against:
  //   - a fake PresenceClient returning peer online:true,
  //   - a contactsList with that one peer,
  //   - a spy MessageService that records flushPeerOnReachable calls.
  // On the stale→online transition pollOnce must dispatch a flush for the peer.
  test('pollOnce triggers flushPeerOnReachable on a stale->online transition',
      () async {
    final peer = 'bb' * 32;

    // In-memory DB only used to construct the spy MessageService — none of its
    // rows are touched because flushPeerOnReachable is overridden to record.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final relay = _FakeRelay();
    final ks = KeyStorage(_MemStorage());
    await IdentityService(ks).loadOrCreate();
    final signing = SigningService(ks);

    final spy = _SpyMessageService(
      crypto: _NoopCrypto(),
      relay: relay,
      dao: ChatsDao(db),
      peerBundleDao: PeerBundleStateDao(db),
      outboxDao: OutboxDao(db),
      myPubkeyHex: 'aa' * 32,
      groupMembersDao: GroupMembersDao(db),
      groupOpsLogDao: GroupOpsLogDao(db),
      signing: signing,
      contactsRepository: ContactsRepository(db),
      profileDao: ProfileDao(db),
    );

    final container = ProviderContainer(overrides: [
      presenceClientProvider.overrideWithValue(
        _FakePresenceClient({
          peer: const PresenceInfo(online: true),
        }, signing),
      ),
      // Override the public list directly — bypasses the migration gate.
      contactsListProvider.overrideWith((ref) async => <model.Contact>[
            model.Contact(pubkeyHex: peer, addedAt: DateTime(2026, 1, 1)),
          ]),
      messageServiceProvider.overrideWith((ref) async => spy),
    ]);
    addTearDown(() async {
      container.dispose();
      await relay.dispose();
      await db.close();
    });

    final notifier = container.read(presenceProvider.notifier);
    // First poll: peer has no prior state → online counts as a transition UP.
    await notifier.pollOnce();
    // flushPeerOnReachable is fired via unawaited(...); let the microtask run.
    await Future<void>.delayed(Duration.zero);

    expect(spy.flushedPeers, contains(peer));
    // State was replaced with the fresh map (Fix 2).
    expect(container.read(presenceProvider)[peer]?.online, isTrue);
  });
}

/// Spy: records flushPeerOnReachable calls; everything else inherits the real
/// MessageService (constructor only wires a relay.inbound listener).
class _SpyMessageService extends MessageService {
  _SpyMessageService({
    required super.crypto,
    required super.relay,
    required super.dao,
    required super.peerBundleDao,
    required super.outboxDao,
    required super.myPubkeyHex,
    required super.groupMembersDao,
    required super.groupOpsLogDao,
    required super.signing,
    required super.contactsRepository,
    required super.profileDao,
  });

  final flushedPeers = <String>[];

  @override
  Future<void> flushPeerOnReachable(String peerPubkeyHex) async {
    flushedPeers.add(peerPubkeyHex);
  }
}

class _FakePresenceClient extends PresenceClient {
  _FakePresenceClient(this._result, SigningService signing)
      : super(baseUri: Uri.parse('http://presence.test'), signing: signing);

  final Map<String, PresenceInfo> _result;

  @override
  Future<Map<String, PresenceInfo>> fetchPresence(List<String> pubkeysHex) async {
    return _result;
  }
}

class _FakeRelay implements RelayClient {
  final StreamController<RelayFrame> _ctrl =
      StreamController<RelayFrame>.broadcast();

  @override
  Stream<RelayFrame> get inbound => _ctrl.stream;

  @override
  Future<void> send({
    required String toPubkeyHex,
    required List<int> envelope,
  }) async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    await _ctrl.close();
  }

  @override
  Uri get relayWsUrl => Uri.parse('ws://test.invalid/');

  @override
  SigningService get signing => throw UnimplementedError();

  @override
  bool get isConnected => true;
}

class _MemStorage implements SecureKeyValueStorage {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
}

/// flushPeerOnReachable is overridden in the spy, so none of these are called.
class _NoopCrypto implements CryptoService {
  @override
  Future<void> initialize() async {}
  @override
  Future<CryptoPreKeyBundle> myPreKeyBundle() => throw UnimplementedError();
  @override
  Future<void> processPeerPreKeyBundle(CryptoPreKeyBundle bundle) async {}
  @override
  Future<List<int>> encrypt({
    required String peerPubkeyHex,
    required List<int> plaintext,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<int>> decrypt({
    required String peerPubkeyHex,
    required List<int> ciphertext,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> forgetPeer(String peerPubkeyHex) async {}
}
