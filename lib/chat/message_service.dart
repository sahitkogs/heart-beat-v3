import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/hex_codec.dart';
import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../data/contacts_repository.dart';
import '../data/group_members_dao.dart';
import '../data/group_ops_log_dao.dart';
import '../data/outbox_dao.dart';
import '../data/peer_bundle_state_dao.dart';
import '../data/profile_dao.dart';
import '../util/display_name.dart';
import '../relay/relay_client.dart';
import '../relay/relay_frames.dart';
import '../services/crypto_service.dart';
import '../services/notifications_service.dart';
import '../services/signing_service.dart';
import '../services/wake_client.dart';
import 'delivery_receipt_debouncer.dart';
import 'group_envelope.dart';
import 'outbox_retransmitter.dart';
import 'pre_key_bootstrap.dart';

/// Orchestrates the encrypt → send → persist and receive → decrypt → persist
/// flows. Constructed once per app session by the messageServiceProvider.
class MessageService {
  MessageService({
    required this.crypto,
    required this.relay,
    required this.dao,
    required this.peerBundleDao,
    required this.outboxDao,
    required this.myPubkeyHex,
    required this.groupMembersDao,
    required this.groupOpsLogDao,
    required this.signing,
    required this.contactsRepository,
    required this.profileDao,
    this.wake,
  }) {
    // Default no-op debouncer so the inbound text branch can fire
    // receiptDebouncer.enqueueDelivered before attachLayerB has run (in tests,
    // or before the provider has finished wiring). Task 12's attachLayerB
    // overwrites this with the real DeliveryReceiptDebouncer.
    receiptDebouncer = DeliveryReceiptDebouncer(null);
    _sub = relay.inbound.listen(_onInbound);
  }

  final CryptoService crypto;
  final RelayClient relay;
  final ChatsDao dao;
  final PeerBundleStateDao peerBundleDao;
  final OutboxDao outboxDao;
  final String myPubkeyHex;
  final GroupMembersDao groupMembersDao;
  final GroupOpsLogDao groupOpsLogDao;
  final SigningService signing;
  final ContactsRepository contactsRepository;
  final ProfileDao profileDao;
  // Optional in tests; production wiring always supplies one via the
  // messageServiceProvider. When null, recipient_offline errors are logged
  // but no wake fallback fires.
  final WakeClient? wake;

  late final StreamSubscription<RelayFrame> _sub;
  static const _uuid = Uuid();

  // Per-peer state needed for the chicken-and-egg bootstrap: libsignal cannot
  // encrypt to a peer until that peer's PreKey bundle has been processed, so
  // we must wait until we receive it before sending the first message.
  //
  // bundleSentAt / peerBundleReceivedAt live in PeerBundleStateDao (T3.1) so a
  // background FCM isolate (Phase 10.3 T7) doesn't re-run the bundle dance on
  // every wake, and state survives app restarts.
  // Only the pending-outbound queue stays in-memory — it's session-scoped and
  // drains the moment the peer's bundle arrives.
  // Entries are JSON inner-envelope bytes (List<int>), not raw strings.
  final Map<String, List<List<int>>> _pendingByPeer = <String, List<List<int>>>{};

  // Late-init so messageServiceProvider can hand back a debouncer that
  // reaches back into `this`. Default is a no-op stub (sender=null);
  // attachLayerB replaces it with the real one in the production wiring.
  late DeliveryReceiptDebouncer receiptDebouncer;
  // Same late-init pattern for the outbox sweeper. Tests that don't call
  // attachLayerB leave this as a Timer-less, never-sweeping placeholder.
  OutboxRetransmitter? _retransmitter;
  OutboxRetransmitter? get retransmitter => _retransmitter;

  /// Called when a chat thread is opened so both sides exchange bundles even
  /// before the first user-typed message. Idempotent.
  Future<void> openChat(String peerPubkeyHex) async {
    _log('openChat ${_short(peerPubkeyHex)}');
    await dao.ensureDirectChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);
  }

  Future<void> sendText({
    required String peerPubkeyHex,
    required String body,
  }) async {
    _log('sendText peer=${_short(peerPubkeyHex)} bodyLen=${body.length}');
    await dao.ensureDirectChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);

    // Single canonical id shared by messages.id, the outbox row, and
    // inner.msgId so the recipient can dedup + receipt this exact message.
    final msgId = _uuid.v4();
    // Compute lamport once; use it for both the persisted row and the
    // JSON inner envelope so they stay in sync.
    final lamport = await dao.bumpLamport(peerPubkeyHex);
    final myName = await currentDisplayName();
    // chatId in the inner envelope is OUR pubkey (the sender's key), so that
    // the receiver's spoof guard (inner.chatId == frame.fromPubkeyHex) passes.
    final jsonBytes = InnerEnvelope.buildText(
      chatId: myPubkeyHex,
      lamport: lamport,
      body: body,
      msgId: msgId,
      senderDisplayName: myName,
    );
    await _persistOutbound(peerPubkeyHex, body, lamport, msgId);

    // Outbox row goes in BEFORE _encryptAndSend. If encrypt or send throws,
    // the row stays; the retransmitter sweeps it on its next pass. If send
    // succeeds, the row stays in implied-`sent` state until a `delivered`
    // receipt arrives and deletes it.
    final now = DateTime.now();
    await outboxDao.insert(
      msgId: msgId,
      peerPubkeyHex: peerPubkeyHex,
      envelopeBytes: jsonBytes,
      createdAt: now,
      nextRetryAt: now.add(const Duration(seconds: 30)),
    );

    final peerState = await peerBundleDao.get(peerPubkeyHex);
    if (peerState?.peerBundleReceivedAt == null) {
      (_pendingByPeer[peerPubkeyHex] ??= <List<int>>[]).add(jsonBytes);
      _log('queued (no peer bundle yet) peer=${_short(peerPubkeyHex)} '
          'queueDepth=${_pendingByPeer[peerPubkeyHex]!.length}');
      return;
    }
    try {
      await _encryptAndSend(peerPubkeyHex, jsonBytes);
      _log('encrypted+sent peer=${_short(peerPubkeyHex)} msgId=${_short(msgId)}');
    } catch (e, st) {
      _log('ENCRYPT FAIL peer=${_short(peerPubkeyHex)} err=$e\n$st');
      // Do not rethrow — the outbox row is the recovery handle. The caller
      // already got UI optimism from _persistOutbound. The retransmitter
      // will retry; if it stays failing for 24h, the tick goes to `failed`.
    }
  }

  /// Creates a group, fans out a signed `group_invite` to every selected member,
  /// and returns the new chatId. Throws ArgumentError if memberPubkeysHex.length > 7
  /// (8-member cap including the creator).
  Future<String> createGroup({
    required String name,
    required List<String> memberPubkeysHex, // does NOT include self
  }) async {
    if (memberPubkeysHex.length > 7) {
      throw ArgumentError('group too big (max 8 including creator)');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('group name must be non-empty');
    }
    final chatId = _randomChatId();
    final now = DateTime.now();
    const initialOpSeq = 1;

    // Local state — chat row, member rows, system message.
    await dao.insertGroupChat(
      chatId: chatId,
      groupName: name,
      creatorPubkeyHex: myPubkeyHex,
      createdAt: now,
      initialOpSeq: initialOpSeq,
    );
    await groupMembersDao.insertMember(
      chatId: chatId, memberPubkeyHex: myPubkeyHex,
      addedByPubkeyHex: myPubkeyHex, addedAt: now,
    );
    for (final m in memberPubkeysHex) {
      await groupMembersDao.insertMember(
        chatId: chatId, memberPubkeyHex: m,
        addedByPubkeyHex: myPubkeyHex, addedAt: now,
      );
    }
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: chatId,
      senderPubkeyHex: myPubkeyHex,
      body: 'You created the group',
      lamport: 0,
      sentAt: now,
      kind: const Value('group_created'),
    ));
    await dao.updateLastMessage(chatId, 'You created the group', now);

    // Build the signed invite. Sort members so canonical bytes are stable.
    final members = [myPubkeyHex, ...memberPubkeysHex];
    final inviteBody = <String, dynamic>{
      'v': 1, 'type': 'group_invite',
      'chatId': chatId, 'lamport': 0,
      'groupName': name,
      'creator': myPubkeyHex,
      'members': members,
      'createdAt': now.toUtc().toIso8601String(),
      'opSeq': initialOpSeq,
      'joinedVia': 'create',
    };
    final canonical = canonicalJsonBytes(inviteBody);
    final sigBytes = await signing.sign(canonical);
    final sigHex = bytesToHex(sigBytes);
    final myName = await currentDisplayName();
    final inviteBytes = InnerEnvelope.buildGroupInvite(
      chatId: chatId, groupName: name, creator: myPubkeyHex,
      members: members, createdAt: now,
      opSeq: initialOpSeq, joinedVia: 'create', sigHex: sigHex,
      senderDisplayName: myName,
    );

    await groupOpsLogDao.append(
      id: _uuid.v4(), chatId: chatId, opSeq: initialOpSeq,
      kind: 'create', targetPubkeyHex: null,
      signerPubkeyHex: myPubkeyHex, signatureHex: sigHex,
      applied: true,
    );

    for (final peer in memberPubkeysHex) {
      try {
        await _maybeSendOwnBundle(peer);
        await _sendOrQueueGroupBytes(peer, inviteBytes);
      } catch (e, st) {
        _log('createGroup fan-out FAIL peer=${_short(peer)} err=$e\n$st');
      }
    }
    _log('createGroup chatId=$chatId members=${memberPubkeysHex.length}+1');
    return chatId;
  }

  /// Send a text message to a group. Loads active members, bumps lamport,
  /// persists the local row, then fans out the JSON `text` envelope to each
  /// non-self active member. Per-peer encrypt/send failures are logged but
  /// don't abort the rest of the fan-out (matches 10.3 single-peer behavior).
  ///
  /// Throws StateError if the chat doesn't exist, isn't a group, or has already
  /// been left.
  Future<void> sendGroupText({
    required String chatId,
    required String body,
  }) async {
    final chat = await dao.getChat(chatId);
    if (chat == null) {
      throw StateError('sendGroupText: unknown chat $chatId');
    }
    if (chat.kind != 'group') {
      throw StateError('sendGroupText: not a group chat $chatId');
    }
    if (chat.leftAt != null) {
      throw StateError('sendGroupText: already left $chatId');
    }

    final active = await groupMembersDao.activeMembers(chatId);
    final recipients = active
        .where((m) => m.memberPubkeyHex != myPubkeyHex)
        .map((m) => m.memberPubkeyHex)
        .toList();

    final lamport = await dao.bumpLamport(chatId);
    final now = DateTime.now();

    // Persist locally before fan-out so the sender's UI updates immediately
    // even if every per-peer send subsequently fails.
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: chatId,
      senderPubkeyHex: myPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: now,
      kind: const Value('text'),
    ));
    await dao.updateLastMessage(chatId, _preview(body), now);

    final myName = await currentDisplayName();
    final jsonBytes = InnerEnvelope.buildText(
      chatId: chatId, lamport: lamport, body: body,
      msgId: _uuid.v4(),
      senderDisplayName: myName,
    );

    _log('sendGroupText chatId=${_short(chatId)} recipients=${recipients.length} '
        'lamport=$lamport bodyLen=${body.length}');

    for (final peer in recipients) {
      try {
        await _maybeSendOwnBundle(peer);
        await _sendOrQueueGroupBytes(peer, jsonBytes);
      } catch (e, st) {
        _log('sendGroupText per-peer FAIL peer=${_short(peer)} err=$e\n$st');
      }
    }
  }

  /// Add a new member to a group. Only the creator can add. Builds and fans out
  /// a signed `member_add` JSON to existing members, plus a signed `group_invite`
  /// JSON (joinedVia='add') to the new member with the updated members list.
  ///
  /// Throws StateError if the chat doesn't exist, isn't a group, or self isn't
  /// the creator. Throws ArgumentError if adding would exceed 8 members or the
  /// target is already an active member.
  Future<void> addMemberToGroup({
    required String chatId,
    required String newMemberPubkeyHex,
  }) async {
    final chat = await dao.getChat(chatId);
    if (chat == null || chat.kind != 'group') {
      throw StateError('addMemberToGroup: not a group $chatId');
    }
    if (chat.creatorPubkeyHex != myPubkeyHex) {
      throw StateError('addMemberToGroup: not creator');
    }
    if (await groupMembersDao.isActiveMember(chatId, newMemberPubkeyHex)) {
      throw ArgumentError('already an active member');
    }
    final activeBefore = await groupMembersDao.activeMembers(chatId);
    if (activeBefore.length >= 8) {
      throw ArgumentError('group full (8 max)');
    }

    final now = DateTime.now();
    final newOpSeq = chat.lastOpSeq + 1;

    // Local state
    await dao.bumpLastOpSeq(chatId, newOpSeq);
    await groupMembersDao.insertMember(
      chatId: chatId, memberPubkeyHex: newMemberPubkeyHex,
      addedByPubkeyHex: myPubkeyHex, addedAt: now,
    );
    final lamport = await dao.bumpLamport(chatId);
    final addedContactList = await contactsRepository.loadAll();
    final addedContact = addedContactList
        .where((c) => c.pubkeyHex == newMemberPubkeyHex)
        .firstOrNull;
    final addedLabel = resolveName(newMemberPubkeyHex, addedContact);
    final addBodyText = 'You added $addedLabel';
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: chatId,
      senderPubkeyHex: myPubkeyHex,
      body: addBodyText,
      lamport: lamport,
      sentAt: now,
      kind: const Value('member_add'),
    ));
    await dao.updateLastMessage(chatId, addBodyText, now);

    // Build + sign member_add (for existing members)
    final addBody = <String, dynamic>{
      'v': 1, 'type': 'member_add',
      'chatId': chatId, 'lamport': lamport,
      'target': newMemberPubkeyHex,
      'addedAt': now.toUtc().toIso8601String(),
      'opSeq': newOpSeq,
    };
    final addCanonical = canonicalJsonBytes(addBody);
    final addSig = await signing.sign(addCanonical);
    final addSigHex = bytesToHex(addSig);
    final myName = await currentDisplayName();
    final addBytes = InnerEnvelope.buildMemberAdd(
      chatId: chatId, lamport: lamport, target: newMemberPubkeyHex,
      addedAt: now, opSeq: newOpSeq, sigHex: addSigHex,
      senderDisplayName: myName,
    );

    // Build + sign group_invite (for new joiner) with the UPDATED members list.
    // Use chat.createdAt so the new joiner sees the same group origin timestamp.
    final updatedMembers = [
      ...activeBefore.map((m) => m.memberPubkeyHex),
      newMemberPubkeyHex,
    ];
    final inviteBody = <String, dynamic>{
      'v': 1, 'type': 'group_invite',
      'chatId': chatId, 'lamport': 0,
      'groupName': chat.groupName!,
      'creator': myPubkeyHex,
      'members': updatedMembers,
      'createdAt': chat.createdAt.toUtc().toIso8601String(),
      'opSeq': newOpSeq,
      'joinedVia': 'add',
    };
    final inviteCanonical = canonicalJsonBytes(inviteBody);
    final inviteSig = await signing.sign(inviteCanonical);
    final inviteSigHex = bytesToHex(inviteSig);
    final inviteBytes = InnerEnvelope.buildGroupInvite(
      chatId: chatId, groupName: chat.groupName!, creator: myPubkeyHex,
      members: updatedMembers, createdAt: chat.createdAt,
      opSeq: newOpSeq, joinedVia: 'add', sigHex: inviteSigHex,
      senderDisplayName: myName,
      // lamport defaults to 0
    );

    // Log both ops
    await groupOpsLogDao.append(
      id: _uuid.v4(), chatId: chatId, opSeq: newOpSeq,
      kind: 'add', targetPubkeyHex: newMemberPubkeyHex,
      signerPubkeyHex: myPubkeyHex, signatureHex: addSigHex,
      applied: true,
    );
    await groupOpsLogDao.append(
      id: _uuid.v4(), chatId: chatId, opSeq: newOpSeq,
      kind: 'create',  // joinedVia='add' is logged as create-shape since it's an invite envelope
      targetPubkeyHex: newMemberPubkeyHex,
      signerPubkeyHex: myPubkeyHex, signatureHex: inviteSigHex,
      applied: true,
    );

    _log('addMemberToGroup chatId=${_short(chatId)} new=${_short(newMemberPubkeyHex)} '
        'opSeq=$newOpSeq');

    // Fan-out
    // 1. member_add to all existing active members EXCEPT self AND new joiner.
    for (final m in activeBefore) {
      if (m.memberPubkeyHex == myPubkeyHex) continue;
      if (m.memberPubkeyHex == newMemberPubkeyHex) continue; // can't happen (just inserted)
      try {
        await _maybeSendOwnBundle(m.memberPubkeyHex);
        await _sendOrQueueGroupBytes(m.memberPubkeyHex, addBytes);
      } catch (e, st) {
        _log('addMember fan-out FAIL existing=${_short(m.memberPubkeyHex)} err=$e\n$st');
      }
    }
    // 2. group_invite to the new joiner. Bundle bootstrap may be required.
    try {
      await _maybeSendOwnBundle(newMemberPubkeyHex);
      await _sendOrQueueGroupBytes(newMemberPubkeyHex, inviteBytes);
    } catch (e, st) {
      _log('addMember fan-out FAIL newJoiner=${_short(newMemberPubkeyHex)} err=$e\n$st');
    }
  }

  /// Remove a member from a group. Only the creator can remove. Builds and
  /// fans out a signed `member_remove` JSON to every current active member
  /// **including the target** (so the target's UI locks down too — spec §7.6).
  ///
  /// Throws StateError if the chat doesn't exist, isn't a group, or self isn't
  /// the creator. Throws ArgumentError if the target is not a currently active
  /// member.
  Future<void> removeMemberFromGroup({
    required String chatId,
    required String targetPubkeyHex,
  }) async {
    final chat = await dao.getChat(chatId);
    if (chat == null || chat.kind != 'group') {
      throw StateError('removeMemberFromGroup: not a group $chatId');
    }
    if (chat.creatorPubkeyHex != myPubkeyHex) {
      throw StateError('removeMemberFromGroup: not creator');
    }
    if (!await groupMembersDao.isActiveMember(chatId, targetPubkeyHex)) {
      throw ArgumentError('not an active member');
    }

    // Snapshot active members BEFORE markRemoved so the target is included in
    // the fan-out list (spec §7.6 step 6 — "fan-out to all current members
    // including the target").
    final activeBefore = await groupMembersDao.activeMembers(chatId);

    final now = DateTime.now();
    final newOpSeq = chat.lastOpSeq + 1;

    // Local state
    await dao.bumpLastOpSeq(chatId, newOpSeq);
    await groupMembersDao.markRemoved(
      chatId: chatId,
      memberPubkeyHex: targetPubkeyHex,
      removedAt: now,
    );
    final lamport = await dao.bumpLamport(chatId);
    final rmContactList = await contactsRepository.loadAll();
    final rmContact = rmContactList
        .where((c) => c.pubkeyHex == targetPubkeyHex)
        .firstOrNull;
    final rmLabel = resolveName(targetPubkeyHex, rmContact);
    final rmBodyText = 'You removed $rmLabel';
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: chatId,
      senderPubkeyHex: myPubkeyHex,
      body: rmBodyText,
      lamport: lamport,
      sentAt: now,
      kind: const Value('member_remove'),
    ));
    await dao.updateLastMessage(chatId, rmBodyText, now);

    // Build + sign member_remove
    final removeBody = <String, dynamic>{
      'v': 1, 'type': 'member_remove',
      'chatId': chatId, 'lamport': lamport,
      'target': targetPubkeyHex,
      'removedAt': now.toUtc().toIso8601String(),
      'opSeq': newOpSeq,
    };
    final canonical = canonicalJsonBytes(removeBody);
    final sigBytes = await signing.sign(canonical);
    final sigHex = bytesToHex(sigBytes);
    final myName = await currentDisplayName();
    final removeBytes = InnerEnvelope.buildMemberRemove(
      chatId: chatId, lamport: lamport, target: targetPubkeyHex,
      removedAt: now, opSeq: newOpSeq, sigHex: sigHex,
      senderDisplayName: myName,
    );

    await groupOpsLogDao.append(
      id: _uuid.v4(), chatId: chatId, opSeq: newOpSeq,
      kind: 'remove', targetPubkeyHex: targetPubkeyHex,
      signerPubkeyHex: myPubkeyHex, signatureHex: sigHex,
      applied: true,
    );

    _log('removeMemberFromGroup chatId=${_short(chatId)} '
        'target=${_short(targetPubkeyHex)} opSeq=$newOpSeq');

    // Fan-out: every active-before member except self, INCLUDING the target.
    for (final m in activeBefore) {
      if (m.memberPubkeyHex == myPubkeyHex) continue;
      try {
        await _maybeSendOwnBundle(m.memberPubkeyHex);
        await _sendOrQueueGroupBytes(m.memberPubkeyHex, removeBytes);
      } catch (e, st) {
        _log('removeMember fan-out FAIL peer=${_short(m.memberPubkeyHex)} '
            'err=$e\n$st');
      }
    }
  }

  /// Leave a group. Any active member (including the creator) can leave.
  /// Builds and fans out a signed `member_leave` JSON to every currently
  /// active member except self. The local `chats.leftAt` is set so the
  /// composer locks in the UI (spec §7.7).
  ///
  /// `member_leave` is lamport-ordered (no `opSeq` bump). The `group_ops_log`
  /// row uses `opSeq: null`.
  ///
  /// Throws StateError if the chat doesn't exist, isn't a group, has already
  /// been left, or self isn't currently an active member.
  Future<void> leaveGroup({required String chatId}) async {
    final chat = await dao.getChat(chatId);
    if (chat == null || chat.kind != 'group') {
      throw StateError('leaveGroup: not a group $chatId');
    }
    if (chat.leftAt != null) {
      throw StateError('leaveGroup: already left $chatId');
    }
    if (!await groupMembersDao.isActiveMember(chatId, myPubkeyHex)) {
      throw StateError('leaveGroup: not an active member');
    }

    // Snapshot recipients BEFORE markRemoved + setLeftAt so we capture the
    // pre-leave membership for fan-out.
    final activeBefore = await groupMembersDao.activeMembers(chatId);

    final now = DateTime.now();
    final lamport = await dao.bumpLamport(chatId);

    // Local state mutations.
    await dao.setLeftAt(chatId, now);
    await groupMembersDao.markRemoved(
      chatId: chatId,
      memberPubkeyHex: myPubkeyHex,
      removedAt: now,
    );
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: chatId,
      senderPubkeyHex: myPubkeyHex,
      body: 'You left',
      lamport: lamport,
      sentAt: now,
      kind: const Value('member_leave'),
    ));
    await dao.updateLastMessage(chatId, 'You left', now);

    // Build + sign member_leave (no opSeq field — leave is lamport-ordered).
    final leaveBody = <String, dynamic>{
      'v': 1, 'type': 'member_leave',
      'chatId': chatId, 'lamport': lamport,
      'leftAt': now.toUtc().toIso8601String(),
    };
    final canonical = canonicalJsonBytes(leaveBody);
    final sigBytes = await signing.sign(canonical);
    final sigHex = bytesToHex(sigBytes);
    final myName = await currentDisplayName();
    final leaveBytes = InnerEnvelope.buildMemberLeave(
      chatId: chatId, lamport: lamport,
      leftAt: now, sigHex: sigHex,
      senderDisplayName: myName,
    );

    await groupOpsLogDao.append(
      id: _uuid.v4(), chatId: chatId, opSeq: null,
      kind: 'leave', targetPubkeyHex: null,
      signerPubkeyHex: myPubkeyHex, signatureHex: sigHex,
      applied: true,
    );

    _log('leaveGroup chatId=${_short(chatId)} lamport=$lamport '
        'recipients=${activeBefore.length - 1}');

    // Fan-out: every active-before member except self.
    for (final m in activeBefore) {
      if (m.memberPubkeyHex == myPubkeyHex) continue;
      try {
        await _maybeSendOwnBundle(m.memberPubkeyHex);
        await _sendOrQueueGroupBytes(m.memberPubkeyHex, leaveBytes);
      } catch (e, st) {
        _log('leaveGroup fan-out FAIL peer=${_short(m.memberPubkeyHex)} '
            'err=$e\n$st');
      }
    }
  }

  String _randomChatId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytesToHex(bytes);
  }

  /// Fan-out helper used by all group send paths. If the peer's bundle hasn't
  /// been received yet, queue the encrypted envelope bytes for later drain.
  /// Otherwise encrypt and send directly.
  Future<void> _sendOrQueueGroupBytes(String peer, List<int> bytes) async {
    final state = await peerBundleDao.get(peer);
    if (state?.peerBundleReceivedAt == null) {
      (_pendingByPeer[peer] ??= <List<int>>[]).add(bytes);
      _log('queued group bytes (no peer bundle yet) peer=${_short(peer)} '
          'queueDepth=${_pendingByPeer[peer]!.length}');
      return;
    }
    await _encryptAndSend(peer, bytes);
  }

  Future<void> _maybeSendOwnBundle(String peerPubkeyHex) async {
    final state = await peerBundleDao.get(peerPubkeyHex);
    if (state?.bundleSentAt != null) {
      _log('bundle already sent to ${_short(peerPubkeyHex)}');
      return;
    }
    final myBundle = await crypto.myPreKeyBundle();
    final stamped = myBundle.copyWithOwner(myPubkeyHex);
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: EnvelopeWire.wrapPreKeyBundle(stamped),
    );
    await peerBundleDao.markBundleSent(peerPubkeyHex);
    _log('sent OUR bundle to ${_short(peerPubkeyHex)} (preKeyId='
        '${stamped.preKeyId} regId=${stamped.registrationId})');
  }

  Future<void> _persistOutbound(
    String peerPubkeyHex,
    String body,
    int lamport,
    String msgId,
  ) async {
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: msgId,
      chatId: peerPubkeyHex,
      senderPubkeyHex: myPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: now,
      kind: const Value('text'),
      knownTicks: const Value(true),
    ));
    await dao.updateLastMessage(peerPubkeyHex, _preview(body), now);
  }

  Future<void> _encryptAndSend(String peerPubkeyHex, List<int> plaintext) async {
    final ciphertext = await crypto.encrypt(
      peerPubkeyHex: peerPubkeyHex,
      plaintext: plaintext,
    );
    final envelope = EnvelopeWire.wrapMessage(ciphertext);
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: envelope,
    );
  }

  void _onInbound(RelayFrame frame) {
    if (frame is DeliverFrame) {
      _handleDeliver(frame);
    } else if (frame is ErrorFrame) {
      _handleError(frame);
    }
  }

  Future<void> _handleError(ErrorFrame frame) async {
    if (frame.code != 'recipient_offline' || frame.toPubkeyHex == null) {
      _log('inbound error code=${frame.code} msg=${frame.message} (no wake)');
      return;
    }
    final peer = frame.toPubkeyHex!;
    final wakeClient = wake;
    if (wakeClient == null) {
      _log('wake_unconfigured peer=${_short(peer)}');
      return;
    }
    // Spec §7m — wake fires on every recipient_offline. Phase 10.4.3a's
    // server-side queue carries the actual envelope (whether the failed
    // send was a bundle or a message); this wake is the "tap the recipient
    // to come online" hint. Empty envelope is fine — server's
    // wakeOfflineRecipient looks up the phonebook entry and pushes a
    // marker-only FCM that the recipient's BG isolate reacts to.
    _log('wake_dispatching peer=${_short(peer)} (unconditional)');
    final result = await wakeClient.wake(
      senderPubkeyHex: myPubkeyHex,
      recipientPubkeyHex: peer,
      envelope: const <int>[],
    );
    switch (result.status) {
      case WakeStatus.ok:
        _log('wake_dispatched peer=${_short(peer)}');
      case WakeStatus.recipientNotRegistered:
        _log('wake_failed_no_phonebook peer=${_short(peer)}');
      case WakeStatus.fcmError:
        _log('wake_failed_fcm peer=${_short(peer)} detail=${result.detail}');
      case WakeStatus.networkError:
        _log('wake_failed_network peer=${_short(peer)} detail=${result.detail}');
      case WakeStatus.serverError:
        _log('wake_failed_server peer=${_short(peer)} detail=${result.detail}');
      case WakeStatus.unauthorized:
        _log('wake_failed_unauthorized peer=${_short(peer)} detail=${result.detail}');
    }
  }

  Future<void> _handleDeliver(DeliverFrame frame) async {
    _log('inbound deliver from=${_short(frame.fromPubkeyHex)} '
        'envBytes=${frame.envelope.length} tag=0x${frame.envelope.isNotEmpty ? frame.envelope.first.toRadixString(16) : "??"}');
    // T8.1 carry-forward — DO NOT ensureDirectChat unconditionally here. A
    // group envelope from a peer should not create a spurious direct-chat
    // tile keyed by that peer. We gate the call into the bundle branch
    // (bundles implicitly open a direct relationship) and into the
    // TextEnvelope branch only when the resolved chat is direct or new.
    final ParsedEnvelope parsed;
    try {
      parsed = EnvelopeWire.parse(frame.envelope);
    } on FormatException catch (e) {
      _log('parse envelope FAIL: $e');
      return;
    }

    if (parsed.isBundle) {
      _log('inbound BUNDLE from=${_short(frame.fromPubkeyHex)} '
          'preKeyId=${parsed.bundle!.preKeyId} regId=${parsed.bundle!.registrationId}');
      // Bundle implicitly opens a direct chat with the sender.
      await dao.ensureDirectChat(frame.fromPubkeyHex);
      final existingState = await peerBundleDao.get(frame.fromPubkeyHex);
      final isFirstFromPeer = existingState?.peerBundleReceivedAt == null;
      try {
        await crypto.processPeerPreKeyBundle(parsed.bundle!);
      } catch (e, st) {
        _log('processBundle FAIL: $e\n$st');
        return;
      }
      await peerBundleDao.markPeerBundleReceived(frame.fromPubkeyHex);
      if (isFirstFromPeer) {
        await peerBundleDao.clearBundleSent(frame.fromPubkeyHex);
        try {
          await _maybeSendOwnBundle(frame.fromPubkeyHex);
        } catch (e, st) {
          _log('re-echo bundle FAIL: $e\n$st');
        }
      }
      final pending = _pendingByPeer.remove(frame.fromPubkeyHex);
      if (pending != null) {
        _log('draining ${pending.length} pending msg(s) to '
            '${_short(frame.fromPubkeyHex)}');
        for (final jsonBytes in pending) {
          try {
            await _encryptAndSend(frame.fromPubkeyHex, jsonBytes);
            _log('drained+sent peer=${_short(frame.fromPubkeyHex)}');
          } catch (e, st) {
            _log('drain ENCRYPT FAIL: $e\n$st');
          }
        }
      }
      return;
    }

    _log('inbound MESSAGE from=${_short(frame.fromPubkeyHex)} '
        'ctBytes=${parsed.ciphertext!.length}');
    final List<int> plaintext;
    try {
      plaintext = await crypto.decrypt(
        peerPubkeyHex: frame.fromPubkeyHex,
        ciphertext: parsed.ciphertext!,
      );
    } catch (e, st) {
      _log('DECRYPT FAIL from=${_short(frame.fromPubkeyHex)} err=$e\n$st');
      return;
    }
    final InnerEnvelope inner;
    try {
      inner = InnerEnvelope.parse(plaintext);
    } on FormatException catch (e) {
      _log('inner_parse_fail from=${_short(frame.fromPubkeyHex)} err=$e');
      return;
    }

    // T6.1 — persist claimedName for the session-sender if they're already
    // a contact. Per spec §3.3, names from non-contacts are dropped.
    await _maybeUpdateClaimedName(
      senderPubkeyHex: frame.fromPubkeyHex,
      senderDisplayName: inner.senderDisplayName,
    );

    if (inner is GroupInviteEnvelope) {
      await _handleGroupInvite(frame, inner);
      return;
    }

    if (inner is MemberAddEnvelope) {
      await _handleMemberAdd(frame, inner);
      return;
    }

    if (inner is MemberRemoveEnvelope) {
      await _handleMemberRemove(frame, inner);
      return;
    }

    if (inner is MemberLeaveEnvelope) {
      await _handleMemberLeave(frame, inner);
      return;
    }

    if (inner is DeliveryReceiptEnvelope) {
      await _handleDeliveryReceipt(frame, inner);
      return;
    }

    if (inner is! TextEnvelope) {
      // Defense-in-depth — all 5 envelope kinds are handled above, so this
      // branch should be unreachable. Log + drop if a new kind appears.
      _log('unhandled_inner_type type=${inner.runtimeType}');
      return;
    }

    // Phase 10.4.3b dedup — Layer A flush + Layer B retransmit can race to
    // deliver the same envelope. A second arrival for the same (sender, msgId)
    // is dropped silently but still triggers a `delivered` receipt because the
    // sender's first receipt may have been lost.
    final existing = await dao.findMessageById(inner.msgId);
    if (existing != null && existing.senderPubkeyHex == frame.fromPubkeyHex) {
      _log('dedup_inbound msgId=${_short(inner.msgId)} '
          'from=${_short(frame.fromPubkeyHex)}');
      receiptDebouncer.enqueueDelivered(
          peer: frame.fromPubkeyHex, msgId: inner.msgId);
      return;
    }

    // T6.2 — route based on chat kind. The inner.chatId tells us which chat
    // this text belongs to; we verify the sender's authority for that chat.
    var chat = await dao.getChat(inner.chatId);
    // T8.1 carry-forward — for a direct-chat envelope (chatId == sender pubkey)
    // that arrived without an existing chat row, lazily create the row. This
    // is the bundle-then-text bootstrap recovery path. Group envelopes
    // (chatId != sender) hit the `unknown_chat` path below as expected.
    if (chat == null && inner.chatId == frame.fromPubkeyHex) {
      await dao.ensureDirectChat(frame.fromPubkeyHex);
      chat = await dao.getChat(inner.chatId);
    }
    if (chat == null) {
      _log('[Group] msg_unknown_chat from=${_short(frame.fromPubkeyHex)} '
          'chat=${_short(inner.chatId)}');
      return;
    }

    if (chat.kind == 'direct') {
      // Existing T4.2 spoof guard: inner.chatId must equal the
      // libsignal-session sender. For direct chats the chatId IS the peer's
      // pubkey, so this rejects messages claiming to come from a third party.
      if (inner.chatId != frame.fromPubkeyHex) {
        _log('direct_chat_id_mismatch from=${_short(frame.fromPubkeyHex)} '
            'innerChatId=${_short(inner.chatId)}');
        return;
      }
    } else if (chat.kind == 'group') {
      // The sender must be an active member of the group they claim to be
      // messaging. Drops messages from removed/never-joined members.
      final active = await groupMembersDao.isActiveMember(
          inner.chatId, frame.fromPubkeyHex);
      if (!active) {
        _log('[Group] msg_from_non_member from=${_short(frame.fromPubkeyHex)} '
            'chat=${_short(inner.chatId)}');
        return;
      }
    } else {
      _log('unknown_chat_kind kind=${chat.kind} chat=${_short(inner.chatId)}');
      return;
    }

    final body = inner.body;
    _log('decrypted from=${_short(frame.fromPubkeyHex)} '
        'chat=${_short(inner.chatId)} bodyLen=${body.length}');

    // Lamport tracking is per-chat (per-group for groups). For direct chats
    // inner.chatId == frame.fromPubkeyHex so behavior matches pre-T6.2.
    final lamport = await dao.observeLamport(inner.chatId, inner.lamport);
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: inner.msgId,
      chatId: inner.chatId,
      senderPubkeyHex: frame.fromPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: now,
      receivedAt: Value(now),
      kind: const Value('text'),
    ));
    // Direct chats only — groups don't get receipts in this phase (§7l).
    if (chat.kind == 'direct') {
      receiptDebouncer.enqueueDelivered(
          peer: frame.fromPubkeyHex, msgId: inner.msgId);
    }
    // Group-tile preview includes the sender prefix so receivers can tell
    // who's talking. Phase 10.4.1 T7.4: use resolveName so the prefix is the
    // human-readable name (displayName ?? claimedName) when available, falling
    // back to truncated hex. Outgoing self-sent group text writes raw preview
    // (handled in sendGroupText).
    final senderContacts = await contactsRepository.loadAll();
    final senderContact = senderContacts
        .where((c) => c.pubkeyHex == frame.fromPubkeyHex)
        .firstOrNull;
    final senderLabel = resolveName(frame.fromPubkeyHex, senderContact);
    final previewText = chat.kind == 'group'
        ? '$senderLabel: ${_preview(body)}'
        : _preview(body);
    await dao.updateLastMessage(inner.chatId, previewText, now);

    // Phase 10.4.1 T13.UX.9 — when the WebSocket inbound path lands while
    // the app is backgrounded (process alive but not foregrounded), the FCM
    // banner path won't fire (relay forwarded over WS instead of waking us),
    // so post a notification here. No-ops when foregrounded.
    try {
      final notifyTitle = chat.kind == 'group'
          ? (chat.groupName ?? 'Group')
          : senderLabel;
      final notifyBody = chat.kind == 'group'
          ? '$senderLabel: ${_preview(body)}'
          : _preview(body);
      await NotificationsService.instance.showMessageNotificationIfBackgrounded(
        title: notifyTitle,
        body: notifyBody,
        payload: inner.chatId,
      );
    } catch (e, st) {
      _log('inbound_notify_failed err=$e\n$st');
    }
  }

  /// T6.1 — handle inbound `group_invite` envelope on the foreground path.
  /// Spec §6.7 + §7.2 + §7.8 verification:
  ///   1. sig verifies under `inv.creator`
  ///   2. `inv.creator` is in local contacts (trust gate)
  ///   3. `inv.members.length <= 8`
  ///   4. self is in `inv.members`
  ///   5. idempotent: skip if `chats` already has this row
  /// Sig-verify failures log + drop AND append `group_ops_log applied=false`.
  /// All other verification failures log + drop (no ops_log row).
  /// Duplicate invites log + drop AND append `applied=true` so the log records
  /// that a second valid invite was seen.
  Future<void> _handleGroupInvite(
    DeliverFrame frame,
    GroupInviteEnvelope inv,
  ) async {
    // 1. Sig verify — rebuild canonical body from the typed fields so the
    // bytes we hash match what the sender canonicalized in createGroup /
    // addMemberToGroup.
    final canonicalBody = <String, dynamic>{
      'v': 1, 'type': 'group_invite',
      'chatId': inv.chatId, 'lamport': inv.lamport,
      'groupName': inv.groupName,
      'creator': inv.creator,
      'members': inv.members,
      'createdAt': inv.createdAt.toUtc().toIso8601String(),
      'opSeq': inv.opSeq,
      'joinedVia': inv.joinedVia,
    };
    final canonical = canonicalJsonBytes(canonicalBody);
    final sigOk = await SigningService.verify(
      publicKeyHex: inv.creator,
      message: canonical,
      signature: hexToBytes(inv.sigHex),
    );
    if (!sigOk) {
      _log('[Group] invite_sig_fail chat=${_short(inv.chatId)} '
          'creator=${_short(inv.creator)}');
      await groupOpsLogDao.append(
        id: _uuid.v4(),
        chatId: inv.chatId,
        opSeq: inv.opSeq,
        kind: 'create',
        targetPubkeyHex: null,
        signerPubkeyHex: inv.creator,
        signatureHex: inv.sigHex,
        applied: false,
      );
      return;
    }

    // 2. Contacts trust gate — the creator must be someone we've scanned.
    final allContacts = await contactsRepository.loadAll();
    final creatorInContacts =
        allContacts.any((c) => c.pubkeyHex == inv.creator);
    if (!creatorInContacts) {
      _log('[Group] creator_not_in_contacts chat=${_short(inv.chatId)} '
          'creator=${_short(inv.creator)}');
      return;
    }

    // 3. Group-size cap.
    if (inv.members.length > 8) {
      _log('[Group] invite_too_many_members chat=${_short(inv.chatId)} '
          'count=${inv.members.length}');
      return;
    }

    // 4. Self must be in the members list (defense in depth — libsignal
    // already addressed us, but in case a sender lies in the JSON).
    if (!inv.members.contains(myPubkeyHex)) {
      _log('[Group] self_not_in_invite chat=${_short(inv.chatId)}');
      return;
    }

    // 5. Idempotency — a duplicate of a previously accepted invite logs an
    // applied=true ops_log entry but does NOT re-insert chat/member rows.
    final existing = await dao.getChat(inv.chatId);
    if (existing != null) {
      _log('[Group] duplicate_invite chat=${_short(inv.chatId)}');
      await groupOpsLogDao.append(
        id: _uuid.v4(),
        chatId: inv.chatId,
        opSeq: inv.opSeq,
        kind: 'create',
        targetPubkeyHex: null,
        signerPubkeyHex: inv.creator,
        signatureHex: inv.sigHex,
        applied: true,
      );
      return;
    }

    // 6. Persist chat + member rows + system message + ops log.
    await dao.insertGroupChat(
      chatId: inv.chatId,
      groupName: inv.groupName,
      creatorPubkeyHex: inv.creator,
      createdAt: inv.createdAt,
      initialOpSeq: inv.opSeq,
    );
    for (final m in inv.members) {
      await groupMembersDao.insertMember(
        chatId: inv.chatId,
        memberPubkeyHex: m,
        addedByPubkeyHex: inv.creator,
        addedAt: inv.createdAt,
      );
    }
    // T11.1: use resolveName (the claimedName we just persisted from
    // _maybeUpdateClaimedName above is the freshest signal we have).
    final creatorContact = allContacts
        .where((c) => c.pubkeyHex == inv.creator)
        .firstOrNull;
    final body =
        '${resolveName(inv.creator, creatorContact)} created the group';
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: inv.chatId,
      senderPubkeyHex: inv.creator,
      body: body,
      lamport: 0,
      sentAt: inv.createdAt,
      receivedAt: Value(now),
      kind: const Value('group_created'),
    ));
    await dao.updateLastMessage(inv.chatId, body, now);
    await groupOpsLogDao.append(
      id: _uuid.v4(),
      chatId: inv.chatId,
      opSeq: inv.opSeq,
      kind: 'create',
      targetPubkeyHex: null,
      signerPubkeyHex: inv.creator,
      signatureHex: inv.sigHex,
      applied: true,
    );
    _log('group_invite accepted chat=${_short(inv.chatId)} '
        'creator=${_short(inv.creator)} members=${inv.members.length}');
  }

  /// T6.3 — handle inbound `member_add` envelope on the foreground path.
  /// Spec §6.7 + §7.8 + §7.9 verification:
  ///   1. chat must exist locally and be `kind='group'`
  ///   2. signer (libsignal-session sender) must equal `chats.creator_pubkey_hex`
  ///   3. Ed25519 sig over canonical bytes verifies under the creator pubkey
  ///   4. opSeq window:
  ///      - `<= chat.lastOpSeq` → drop with `op_seq_stale` (no ops_log row)
  ///      - `> chat.lastOpSeq + 1` → accept but log `op_seq_gap`
  ///      - `== chat.lastOpSeq + 1` → normal accept
  /// Sig-verify failures log + drop AND append `group_ops_log applied=false`.
  /// On accept: insert the new member row, bump lastOpSeq, insert the system
  /// message, append `group_ops_log applied=true`.
  Future<void> _handleMemberAdd(
    DeliverFrame frame,
    MemberAddEnvelope inv,
  ) async {
    final chat = await dao.getChat(inv.chatId);
    if (chat == null) {
      _log('[Group] member_add_unknown_chat chat=${_short(inv.chatId)} '
          'from=${_short(frame.fromPubkeyHex)}');
      return;
    }
    if (chat.kind != 'group') {
      _log('[Group] member_add_wrong_kind chat=${_short(inv.chatId)} '
          'kind=${chat.kind}');
      return;
    }
    // Signer must be the group creator. The libsignal-session sender
    // (frame.fromPubkeyHex) is the cryptographic identity of who handed us
    // this envelope; spec §6.7 says sig verifies under chats.creator_pubkey_hex,
    // so we additionally require the session-sender to equal the creator.
    if (frame.fromPubkeyHex != chat.creatorPubkeyHex) {
      _log('[Group] member_add_signer_not_creator chat=${_short(inv.chatId)} '
          'from=${_short(frame.fromPubkeyHex)} '
          'creator=${_short(chat.creatorPubkeyHex ?? "")}');
      return;
    }

    // Rebuild canonical bytes from the typed fields (no `sig`) and verify.
    final canonicalBody = <String, dynamic>{
      'v': 1, 'type': 'member_add',
      'chatId': inv.chatId, 'lamport': inv.lamport,
      'target': inv.target,
      'addedAt': inv.addedAt.toUtc().toIso8601String(),
      'opSeq': inv.opSeq,
    };
    final canonical = canonicalJsonBytes(canonicalBody);
    final sigOk = await SigningService.verify(
      publicKeyHex: chat.creatorPubkeyHex!,
      message: canonical,
      signature: hexToBytes(inv.sigHex),
    );
    if (!sigOk) {
      _log('[Group] member_add_sig_fail chat=${_short(inv.chatId)} '
          'target=${_short(inv.target)}');
      await groupOpsLogDao.append(
        id: _uuid.v4(),
        chatId: inv.chatId,
        opSeq: inv.opSeq,
        kind: 'add',
        targetPubkeyHex: inv.target,
        signerPubkeyHex: chat.creatorPubkeyHex!,
        signatureHex: inv.sigHex,
        applied: false,
      );
      return;
    }

    // opSeq window. Spec §7.9:
    //   <= last_op_seq           → drop with op_seq_stale (no ops_log row)
    //   > last_op_seq + 1        → accept, but log op_seq_gap
    //   == last_op_seq + 1       → normal accept
    if (inv.opSeq <= chat.lastOpSeq) {
      _log('[Group] op_seq_stale chat=${_short(inv.chatId)} '
          'incoming=${inv.opSeq} local=${chat.lastOpSeq}');
      return;
    }
    if (inv.opSeq > chat.lastOpSeq + 1) {
      _log('[Group] op_seq_gap chat=${_short(inv.chatId)} '
          'incoming=${inv.opSeq} local=${chat.lastOpSeq}');
      // fall through and accept
    }

    // Accept: insert member row + bump opSeq + system message + ops log.
    await groupMembersDao.insertMember(
      chatId: inv.chatId,
      memberPubkeyHex: inv.target,
      addedByPubkeyHex: chat.creatorPubkeyHex!,
      addedAt: inv.addedAt,
    );
    await dao.bumpLastOpSeq(inv.chatId, inv.opSeq);

    // T11.1: system row uses resolveName for creator + target.
    final memberAddContacts = await contactsRepository.loadAll();
    final addCreatorContact = memberAddContacts
        .where((c) => c.pubkeyHex == chat.creatorPubkeyHex!)
        .firstOrNull;
    final addTargetContact = memberAddContacts
        .where((c) => c.pubkeyHex == inv.target)
        .firstOrNull;
    final addCreatorLabel =
        resolveName(chat.creatorPubkeyHex!, addCreatorContact);
    final addTargetLabel = resolveName(inv.target, addTargetContact);
    final body = inv.target == myPubkeyHex
        ? '$addCreatorLabel added you'
        : '$addCreatorLabel added $addTargetLabel';
    final now = DateTime.now();
    // Observe inv.lamport so subsequent text messages in this group don't
    // accidentally get a smaller lamport than the system row.
    final lamport = await dao.observeLamport(inv.chatId, inv.lamport);
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: inv.chatId,
      senderPubkeyHex: chat.creatorPubkeyHex!,
      body: body,
      lamport: lamport,
      sentAt: inv.addedAt,
      receivedAt: Value(now),
      kind: const Value('member_add'),
    ));
    await dao.updateLastMessage(inv.chatId, body, now);
    await groupOpsLogDao.append(
      id: _uuid.v4(),
      chatId: inv.chatId,
      opSeq: inv.opSeq,
      kind: 'add',
      targetPubkeyHex: inv.target,
      signerPubkeyHex: chat.creatorPubkeyHex!,
      signatureHex: inv.sigHex,
      applied: true,
    );
    _log('member_add accepted chat=${_short(inv.chatId)} '
        'target=${_short(inv.target)} opSeq=${inv.opSeq}');
  }

  /// T6.4 — handle inbound `member_remove` envelope on the foreground path.
  /// Spec §6.7 + §7.8 + §7.9 verification:
  ///   1. chat must exist locally and be `kind='group'`
  ///   2. signer (libsignal-session sender) must equal `chats.creator_pubkey_hex`
  ///   3. Ed25519 sig over canonical bytes verifies under the creator pubkey
  ///   4. `target ∈ group_members` (any row, active or already-removed —
  ///      double-remove retransmits must be idempotent, not dropped)
  ///   5. opSeq window:
  ///      - `<= chat.lastOpSeq` → drop with `op_seq_stale` (no ops_log row)
  ///      - `> chat.lastOpSeq + 1` → accept but log `op_seq_gap`
  ///      - `== chat.lastOpSeq + 1` → normal accept
  /// Sig-verify failures log + drop AND append `group_ops_log applied=false`.
  /// On accept: mark the target removed, bump lastOpSeq, if target==self also
  /// set `chats.leftAt`, insert system message, append `group_ops_log applied=true`.
  Future<void> _handleMemberRemove(
    DeliverFrame frame,
    MemberRemoveEnvelope inv,
  ) async {
    final chat = await dao.getChat(inv.chatId);
    if (chat == null) {
      _log('[Group] member_remove_unknown_chat chat=${_short(inv.chatId)} '
          'from=${_short(frame.fromPubkeyHex)}');
      return;
    }
    if (chat.kind != 'group') {
      _log('[Group] member_remove_wrong_kind chat=${_short(inv.chatId)} '
          'kind=${chat.kind}');
      return;
    }
    if (frame.fromPubkeyHex != chat.creatorPubkeyHex) {
      _log('[Group] member_remove_signer_not_creator chat=${_short(inv.chatId)} '
          'from=${_short(frame.fromPubkeyHex)} '
          'creator=${_short(chat.creatorPubkeyHex ?? "")}');
      return;
    }

    // Rebuild canonical bytes from the typed fields (no `sig`) and verify.
    // Note: field is `removedAt` (not `addedAt`).
    final canonicalBody = <String, dynamic>{
      'v': 1, 'type': 'member_remove',
      'chatId': inv.chatId, 'lamport': inv.lamport,
      'target': inv.target,
      'removedAt': inv.removedAt.toUtc().toIso8601String(),
      'opSeq': inv.opSeq,
    };
    final canonical = canonicalJsonBytes(canonicalBody);
    final sigOk = await SigningService.verify(
      publicKeyHex: chat.creatorPubkeyHex!,
      message: canonical,
      signature: hexToBytes(inv.sigHex),
    );
    if (!sigOk) {
      _log('[Group] member_remove_sig_fail chat=${_short(inv.chatId)} '
          'target=${_short(inv.target)}');
      await groupOpsLogDao.append(
        id: _uuid.v4(),
        chatId: inv.chatId,
        opSeq: inv.opSeq,
        kind: 'remove',
        targetPubkeyHex: inv.target,
        signerPubkeyHex: chat.creatorPubkeyHex!,
        signatureHex: inv.sigHex,
        applied: false,
      );
      return;
    }

    // Spec §6.7: target must be in `group_members` (any row, active OR already
    // removed). Using `allMembers` here — NOT `isActiveMember` — keeps retrans-
    // mit double-removes idempotent (markRemoved becomes a no-op update rather
    // than us mistakenly dropping them as unknown_target).
    final all = await groupMembersDao.allMembers(inv.chatId);
    final targetExists = all.any((m) => m.memberPubkeyHex == inv.target);
    if (!targetExists) {
      _log('[Group] member_remove_unknown_target chat=${_short(inv.chatId)} '
          'target=${_short(inv.target)}');
      return;
    }

    // opSeq window. Spec §7.9 — same rules as member_add.
    if (inv.opSeq <= chat.lastOpSeq) {
      _log('[Group] op_seq_stale chat=${_short(inv.chatId)} '
          'incoming=${inv.opSeq} local=${chat.lastOpSeq}');
      return;
    }
    if (inv.opSeq > chat.lastOpSeq + 1) {
      _log('[Group] op_seq_gap chat=${_short(inv.chatId)} '
          'incoming=${inv.opSeq} local=${chat.lastOpSeq}');
      // fall through and accept
    }

    // Accept: mark removed + bump opSeq + (if self) setLeftAt + system msg + ops log.
    final now = DateTime.now();
    await groupMembersDao.markRemoved(
      chatId: inv.chatId,
      memberPubkeyHex: inv.target,
      removedAt: inv.removedAt,
    );
    if (inv.target == myPubkeyHex) {
      await dao.setLeftAt(inv.chatId, now);
    }
    await dao.bumpLastOpSeq(inv.chatId, inv.opSeq);

    // T11.1: system row uses resolveName for creator + target.
    final memberRmContacts = await contactsRepository.loadAll();
    final rmCreatorContact = memberRmContacts
        .where((c) => c.pubkeyHex == chat.creatorPubkeyHex!)
        .firstOrNull;
    final rmTargetContact = memberRmContacts
        .where((c) => c.pubkeyHex == inv.target)
        .firstOrNull;
    final rmCreatorLabel =
        resolveName(chat.creatorPubkeyHex!, rmCreatorContact);
    final rmTargetLabel = resolveName(inv.target, rmTargetContact);
    final body = inv.target == myPubkeyHex
        ? '$rmCreatorLabel removed you'
        : '$rmCreatorLabel removed $rmTargetLabel';
    final lamport = await dao.observeLamport(inv.chatId, inv.lamport);
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: inv.chatId,
      senderPubkeyHex: chat.creatorPubkeyHex!,
      body: body,
      lamport: lamport,
      sentAt: inv.removedAt,
      receivedAt: Value(now),
      kind: const Value('member_remove'),
    ));
    await dao.updateLastMessage(inv.chatId, body, now);
    await groupOpsLogDao.append(
      id: _uuid.v4(),
      chatId: inv.chatId,
      opSeq: inv.opSeq,
      kind: 'remove',
      targetPubkeyHex: inv.target,
      signerPubkeyHex: chat.creatorPubkeyHex!,
      signatureHex: inv.sigHex,
      applied: true,
    );
    _log('member_remove accepted chat=${_short(inv.chatId)} '
        'target=${_short(inv.target)} opSeq=${inv.opSeq}');
  }

  /// T6.5 — handle inbound `member_leave` envelope on the foreground path.
  /// Spec §6.5 + §6.7 + §7.8 + §7.9 verification:
  ///   1. chat must exist locally and be `kind='group'`
  ///   2. the signer (libsignal-session sender) must currently be an active
  ///      member of this group — the leaver IS the signer
  ///   3. Ed25519 sig over canonical bytes verifies under the SIGNER'S pubkey
  ///      (not the creator's — leave is signed by the leaver)
  /// Leave is lamport-ordered, NOT opSeq-ordered. No opSeq window check, no
  /// `lastOpSeq` bump. The `group_ops_log` row uses `opSeq: null` and
  /// `targetPubkeyHex: null` (signer == leaver, no separate target field).
  ///
  /// Sig-verify failures log + drop AND append `group_ops_log applied=false`.
  /// Idempotency: a duplicate leave re-delivery is dropped by the "currently
  /// active member" check (we marked the signer inactive on first delivery).
  Future<void> _handleMemberLeave(
    DeliverFrame frame,
    MemberLeaveEnvelope inv,
  ) async {
    final chat = await dao.getChat(inv.chatId);
    if (chat == null) {
      _log('[Group] member_leave_unknown_chat chat=${_short(inv.chatId)} '
          'from=${_short(frame.fromPubkeyHex)}');
      return;
    }
    if (chat.kind != 'group') {
      _log('[Group] member_leave_wrong_kind chat=${_short(inv.chatId)} '
          'kind=${chat.kind}');
      return;
    }
    // Spec §6.7: the leaver must currently be an active member. This also
    // gives us idempotency for free — a replayed leave finds the signer
    // already inactive and is dropped here.
    final isActive = await groupMembersDao.isActiveMember(
        inv.chatId, frame.fromPubkeyHex);
    if (!isActive) {
      _log('[Group] member_leave_not_active chat=${_short(inv.chatId)} '
          'signer=${_short(frame.fromPubkeyHex)}');
      return;
    }

    // Rebuild canonical bytes from the typed fields (no `sig`) and verify
    // under the SIGNER's pubkey — for member_leave the signer signs under
    // their OWN identity, not the creator's.
    final canonicalBody = <String, dynamic>{
      'v': 1, 'type': 'member_leave',
      'chatId': inv.chatId, 'lamport': inv.lamport,
      'leftAt': inv.leftAt.toUtc().toIso8601String(),
    };
    final canonical = canonicalJsonBytes(canonicalBody);
    final sigOk = await SigningService.verify(
      publicKeyHex: frame.fromPubkeyHex,
      message: canonical,
      signature: hexToBytes(inv.sigHex),
    );
    if (!sigOk) {
      _log('[Group] member_leave_sig_fail chat=${_short(inv.chatId)} '
          'signer=${_short(frame.fromPubkeyHex)}');
      await groupOpsLogDao.append(
        id: _uuid.v4(),
        chatId: inv.chatId,
        opSeq: null,
        kind: 'leave',
        targetPubkeyHex: null,
        signerPubkeyHex: frame.fromPubkeyHex,
        signatureHex: inv.sigHex,
        applied: false,
      );
      return;
    }

    // Accept: mark the signer removed, insert system message, append ops_log.
    // No lastOpSeq bump (leave has no opSeq).
    final now = DateTime.now();
    await groupMembersDao.markRemoved(
      chatId: inv.chatId,
      memberPubkeyHex: frame.fromPubkeyHex,
      removedAt: inv.leftAt,
    );

    // T11.1: system row uses resolveName for the leaver.
    final leaveContacts = await contactsRepository.loadAll();
    final leaverContact = leaveContacts
        .where((c) => c.pubkeyHex == frame.fromPubkeyHex)
        .firstOrNull;
    final leaverLabel = resolveName(frame.fromPubkeyHex, leaverContact);
    final body = '$leaverLabel left';
    final lamport = await dao.observeLamport(inv.chatId, inv.lamport);
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: inv.chatId,
      senderPubkeyHex: frame.fromPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: inv.leftAt,
      receivedAt: Value(now),
      kind: const Value('member_leave'),
    ));
    await dao.updateLastMessage(inv.chatId, body, now);
    await groupOpsLogDao.append(
      id: _uuid.v4(),
      chatId: inv.chatId,
      opSeq: null,
      kind: 'leave',
      targetPubkeyHex: null,
      signerPubkeyHex: frame.fromPubkeyHex,
      signatureHex: inv.sigHex,
      applied: true,
    );
    _log('member_leave accepted chat=${_short(inv.chatId)} '
        'signer=${_short(frame.fromPubkeyHex)}');
  }

  /// Inbound `delivery_receipt` — peer is acking message(s) we sent.
  /// Spec §7e: spoof-guarded, monotonic. The outbox row is deleted on the
  /// FIRST receipt (delivered or read); subsequent receipts for the same
  /// msgId fall back to the messages table for spoof verification so a
  /// `read` arriving after `delivered` still advances the tick.
  Future<void> _handleDeliveryReceipt(
    DeliverFrame frame,
    DeliveryReceiptEnvelope inner,
  ) async {
    for (final mid in inner.msgIds) {
      final newState = inner.kind == ReceiptKind.read
          ? DeliveryState.read
          : DeliveryState.delivered;

      final outboxRow = await outboxDao.findByMsgId(mid);
      if (outboxRow != null) {
        // Primary spoof guard: ack must come from the peer we sent to.
        if (outboxRow.peerPubkeyHex != frame.fromPubkeyHex) {
          _log('receipt_peer_mismatch msgId=${_short(mid)} '
              'sentTo=${_short(outboxRow.peerPubkeyHex)} '
              'from=${_short(frame.fromPubkeyHex)}');
          continue;
        }
        await dao.advanceDeliveryStateIfHigher(mid, newState);
        await outboxDao.deleteByMsgId(mid);
        _log('receipt_applied msgId=${_short(mid)} '
            'kind=${inner.kind.name} from=${_short(frame.fromPubkeyHex)}');
        continue;
      }

      // Outbox row already gone — typically a `read` arriving after
      // `delivered` already drained the row. Fall back to the messages
      // table for spoof verification: the ack peer must equal the chatId
      // (direct chat) of an outbound message we sent.
      final msg = await dao.findMessageById(mid);
      if (msg == null) {
        _log('receipt_unknown_msgId msgId=${_short(mid)} '
            'from=${_short(frame.fromPubkeyHex)}');
        continue;
      }
      if (msg.senderPubkeyHex != myPubkeyHex ||
          msg.chatId != frame.fromPubkeyHex) {
        _log('receipt_peer_mismatch_fallback msgId=${_short(mid)} '
            'msgChat=${_short(msg.chatId)} '
            'from=${_short(frame.fromPubkeyHex)}');
        continue;
      }
      await dao.advanceDeliveryStateIfHigher(mid, newState);
      _log('receipt_applied_no_outbox msgId=${_short(mid)} '
          'kind=${inner.kind.name} from=${_short(frame.fromPubkeyHex)}');
    }
  }

  /// Reads the local user's current display name from drift. Returns null
  /// if no profile row exists (shouldn't happen post-bootstrap — the
  /// StartupRouter forces DisplayNameSetupScreen before any chat path is
  /// reachable — but defensive). Reading per-send is cheap (single SQLite
  /// lookup, microseconds) and stays fresh after rename.
  Future<String?> currentDisplayName() async {
    final row = await profileDao.get();
    return row?.displayName;
  }

  /// Persists the sender's claimedName to contacts when an inbound envelope
  /// carries one. Spec §3.3: names from non-contacts are silently dropped.
  /// Whitespace-only is treated as missing. Names over 100 chars are
  /// truncated. Never touches `displayName` (user-chosen winning value).
  Future<void> _maybeUpdateClaimedName({
    required String senderPubkeyHex,
    required String? senderDisplayName,
  }) async {
    if (senderDisplayName == null) return;
    final trimmed = senderDisplayName.trim();
    if (trimmed.isEmpty) return;
    final capped = trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
    final contacts = await contactsRepository.loadAll();
    final exists = contacts.any((c) => c.pubkeyHex == senderPubkeyHex);
    if (!exists) {
      _log('claimed_name_unknown_sender from=${_short(senderPubkeyHex)}');
      return;
    }
    await contactsRepository.updateClaimedName(senderPubkeyHex, capped);
  }

  String _preview(String body) =>
      body.length <= 80 ? body : '${body.substring(0, 77)}...';

  static String _short(String hex) =>
      hex.length >= 16 ? '${hex.substring(0, 6)}…${hex.substring(hex.length - 6)}' : hex;

  static void _log(String msg) {
    // ignore: avoid_print
    print('[MS] $msg');
  }

  /// Constructs and assigns the receipt debouncer + outbox retransmitter
  /// after the MessageService is built. Two-step wiring because both
  /// helpers need a `this` reference, which a constructor can't supply.
  /// Called by messageServiceProvider in production; tests that need the
  /// real (non-stub) helpers can also opt in.
  void attachLayerB() {
    receiptDebouncer = DeliveryReceiptDebouncer(
      _MessageServiceReceiptSender(this),
      outbox: outboxDao,
    );
    _retransmitter = OutboxRetransmitter(
      outbox: outboxDao,
      chats: dao,
      sender: _MessageServiceRetransmitSender(this),
    );
    _retransmitter!.start();
  }

  Future<void> dispose() async {
    _retransmitter?.stop();
    receiptDebouncer.dispose();
    await _sub.cancel();
  }

  /// Drop all crypto + bundle-exchange state for [peerPubkeyHex] so a future
  /// re-pairing (delete + re-add, or peer rotating identity by reinstalling)
  /// starts a fresh X3DH handshake. Without this, `_maybeSendOwnBundle`'s
  /// `bundleSentAt != null` early-return + a stale `peerBundleReceivedAt`
  /// combine to silently route sends into an unrecoverable session.
  Future<void> forgetPeer(String peerPubkeyHex) async {
    _pendingByPeer.remove(peerPubkeyHex);
    await outboxDao.markPeerFailed(peerPubkeyHex);
    await peerBundleDao.deleteByPubkey(peerPubkeyHex);
    await crypto.forgetPeer(peerPubkeyHex);
    _log('forgetPeer cleared bundle+session+outbox for ${_short(peerPubkeyHex)}');
  }
}

class _MessageServiceReceiptSender implements ReceiptSender {
  _MessageServiceReceiptSender(this._svc);
  final MessageService _svc;
  @override
  Future<String?> currentDisplayName() => _svc.currentDisplayName();
  @override
  Future<void> encryptAndSend(String peer, List<int> envelopeBytes) =>
      _svc._encryptAndSend(peer, envelopeBytes);
}

class _MessageServiceRetransmitSender implements RetransmitSender {
  _MessageServiceRetransmitSender(this._svc);
  final MessageService _svc;
  @override
  Future<void> sendOnce(String peer, List<int> envelopeBytes) =>
      _svc._encryptAndSend(peer, envelopeBytes);
}
