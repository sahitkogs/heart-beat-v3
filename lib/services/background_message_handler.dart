import 'dart:convert' show base64Decode;

import 'package:drift/drift.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../chat/group_envelope.dart';
import '../chat/pre_key_bootstrap.dart';
import '../core/hex_codec.dart';
import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../data/contacts_repository.dart';
import '../data/group_members_dao.dart';
import '../data/group_ops_log_dao.dart';
import '../data/peer_bundle_state_dao.dart';
import '../firebase_options.dart';
import 'key_storage.dart';
import 'libsignal_crypto_service.dart';
import 'notifications_service.dart';
import 'signing_service.dart';
import 'wake_client.dart';

const _uuid = Uuid();

/// Top-level entry point Android invokes when the app is killed or
/// backgrounded and an FCM data message arrives. MUST be a top-level
/// function annotated with `@pragma('vm:entry-point')` so the AOT compiler
/// keeps it in the binary.
///
/// Wake payload format (set in [WakeClient.wake]):
///   `senderPubkey(32 bytes) || envelope(EnvelopeWire bytes)`
///
/// Splits the sender prefix, parses the envelope, decrypts (or processes a
/// bundle), persists to drift, and shows a notification. Always cleans up
/// its own DB connection.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already-initialized is fine; Android can call us during a hot lifecycle.
    _log('Firebase.initializeApp: $e');
  }
  await processFcmMessage(message, showNotification: true);
}

/// Foreground variant: called by `FirebaseMessaging.onMessage` when the
/// app is open. Persists the message but does NOT show a banner — the chat
/// UI will reflect it automatically via the drift `watch()` streams.
Future<void> firebaseMessagingForegroundHandler(RemoteMessage message) async {
  await processFcmMessage(message, showNotification: false);
}

/// Shared core of both handlers. Exposed so tests can drive it without a
/// real Firebase invocation.
Future<void> processFcmMessage(
  RemoteMessage message, {
  required bool showNotification,
}) async {
  final raw = message.data['hb_payload'];
  if (raw is! String || raw.isEmpty) {
    _log('missing hb_payload in FCM data');
    return;
  }

  final Uint8List wakePayload;
  try {
    wakePayload = base64Decode(raw);
  } catch (e) {
    _log('base64 decode failed: $e');
    return;
  }

  if (wakePayload.length < wakeSenderPubkeyBytes + 1) {
    _log('wake payload too short: ${wakePayload.length}B');
    return;
  }

  final senderPubkeyHex = bytesToHex(
    wakePayload.sublist(0, wakeSenderPubkeyBytes),
  );
  final envelopeBytes = wakePayload.sublist(wakeSenderPubkeyBytes);

  ParsedEnvelope parsed;
  try {
    parsed = EnvelopeWire.parse(envelopeBytes);
  } catch (e) {
    _log('envelope parse failed: $e');
    return;
  }

  // Open a fresh DB connection for this isolate. SQLite WAL mode means a
  // concurrent main-isolate connection is fine; both write to the same file
  // and serialize via WAL.
  final db = AppDatabase();
  try {
    final dao = ChatsDao(db);
    final groupMembersDao = GroupMembersDao(db);
    final groupOpsLogDao = GroupOpsLogDao(db);
    // Carry-forward (session 2): `ensureDirectChat(senderPubkeyHex)` here
    // creates a spurious direct-chat row for the SENDER pubkey on every
    // inbound (including group deliveries). Benign but cosmetic — flagged
    // for the end-of-phase quality pass to gate on inner envelope type.
    await dao.ensureDirectChat(senderPubkeyHex);

    final peerBundleDao = PeerBundleStateDao(db);
    final crypto = LibsignalCryptoService(db);
    await crypto.initialize();

    if (parsed.isBundle) {
      try {
        await crypto.processPeerPreKeyBundle(parsed.bundle!);
        await peerBundleDao.markPeerBundleReceived(senderPubkeyHex);
        _log('processed peer bundle from=${_short(senderPubkeyHex)}');
      } catch (e, st) {
        _log('process bundle FAILED from=${_short(senderPubkeyHex)} '
            'err=$e\n$st');
      }
      // Don't auto-reply with OUR bundle from background — the sender will
      // hit recipient_offline again next time they try and re-bridge then.
      // No notification for a bundle alone (it carries no message content).
      return;
    }

    // Message path.
    final List<int> plaintext;
    try {
      plaintext = await crypto.decrypt(
        peerPubkeyHex: senderPubkeyHex,
        ciphertext: parsed.ciphertext!,
      );
    } catch (e, st) {
      _log('decrypt FAILED from=${_short(senderPubkeyHex)} err=$e\n$st');
      return;
    }

    final InnerEnvelope inner;
    try {
      inner = InnerEnvelope.parse(plaintext);
    } on FormatException catch (e) {
      _log('inner_parse_fail from=${_short(senderPubkeyHex)} err=$e');
      return;
    }

    // Self-bootstrap our own pubkey for verification gates (self-in-members,
    // target==self self-leave, etc.). Background isolate can run before any
    // UI mounts so we instantiate our own SigningService.
    final signing = SigningService(KeyStorage());
    final myPubkeyHex = await signing.publicKeyHex();

    if (inner is GroupInviteEnvelope) {
      await _handleGroupInvite(
        senderPubkeyHex: senderPubkeyHex,
        inv: inner,
        dao: dao,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
        db: db,
        myPubkeyHex: myPubkeyHex,
        showNotification: showNotification,
      );
      return;
    }

    if (inner is MemberAddEnvelope) {
      await _handleMemberAdd(
        senderPubkeyHex: senderPubkeyHex,
        inv: inner,
        dao: dao,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
        myPubkeyHex: myPubkeyHex,
      );
      return;
    }

    if (inner is MemberRemoveEnvelope) {
      await _handleMemberRemove(
        senderPubkeyHex: senderPubkeyHex,
        inv: inner,
        dao: dao,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
        myPubkeyHex: myPubkeyHex,
      );
      return;
    }

    if (inner is MemberLeaveEnvelope) {
      await _handleMemberLeave(
        senderPubkeyHex: senderPubkeyHex,
        inv: inner,
        dao: dao,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
      );
      return;
    }

    if (inner is! TextEnvelope) {
      // Defense-in-depth — all 5 envelope kinds are handled above, so this
      // branch should be unreachable. Log + drop if a new kind appears.
      _log('unhandled_inner_type type=${inner.runtimeType}');
      return;
    }

    // T8.1 — route based on chat kind, mirroring foreground _handleDeliver.
    final chat = await dao.getChat(inner.chatId);
    if (chat == null) {
      _log('[Group] msg_unknown_chat from=${_short(senderPubkeyHex)} '
          'chat=${_short(inner.chatId)}');
      return;
    }

    if (chat.kind == 'direct') {
      // Existing T4.2 spoof guard: inner.chatId must equal the
      // libsignal-session sender. For direct chats chatId IS the peer's
      // pubkey, so this rejects messages claiming to come from a third party.
      if (inner.chatId != senderPubkeyHex) {
        _log('direct_chat_id_mismatch from=${_short(senderPubkeyHex)} '
            'innerChatId=${_short(inner.chatId)}');
        return;
      }
    } else if (chat.kind == 'group') {
      final active = await groupMembersDao.isActiveMember(
          inner.chatId, senderPubkeyHex);
      if (!active) {
        _log('[Group] msg_from_non_member from=${_short(senderPubkeyHex)} '
            'chat=${_short(inner.chatId)}');
        return;
      }
    } else {
      _log('unknown_chat_kind kind=${chat.kind} chat=${_short(inner.chatId)}');
      return;
    }

    final body = inner.body;
    final now = DateTime.now();
    final lamport = await dao.observeLamport(inner.chatId, inner.lamport);
    await dao.insertMessage(
      MessagesCompanion.insert(
        id: _uuid.v4(),
        chatId: inner.chatId,
        senderPubkeyHex: senderPubkeyHex,
        body: body,
        lamport: lamport,
        sentAt: now,
        receivedAt: Value(now),
        kind: const Value('text'),
      ),
    );
    // Group-tile preview must include the sender prefix (mirrors foreground
    // _handleDeliver TextEnvelope branch in message_service.dart).
    final preview = chat.kind == 'group'
        ? '${_short(senderPubkeyHex)}: ${_preview(body)}'
        : _preview(body);
    await dao.updateLastMessage(inner.chatId, preview, now);
    _log('persisted message from=${_short(senderPubkeyHex)} '
        'chat=${_short(inner.chatId)} kind=${chat.kind} bodyLen=${body.length}');

    if (showNotification) {
      String title;
      String notifyBody;
      if (chat.kind == 'group') {
        title = chat.groupName ?? _short(inner.chatId);
        notifyBody = '${_short(senderPubkeyHex)}: $body';
      } else {
        final repo = ContactsRepository(db);
        final contacts = await repo.loadAll();
        final isKnown = contacts.any((c) => c.pubkeyHex == senderPubkeyHex);
        title = isKnown
            ? _short(senderPubkeyHex)
            : 'Unknown ${_short(senderPubkeyHex)}';
        notifyBody = body;
      }
      try {
        await _showMessageNotification(
          title: title,
          body: notifyBody,
          payload: inner.chatId,
        );
      } catch (e, st) {
        _log('show notification FAILED: $e\n$st');
      }
    }
  } finally {
    await db.close();
  }
}

/// T8.1 — mirror of MessageService._handleGroupInvite. See message_service.dart
/// lines 858–980 for design notes. Reproduced (not extracted) per carry-forward.
Future<void> _handleGroupInvite({
  required String senderPubkeyHex,
  required GroupInviteEnvelope inv,
  required ChatsDao dao,
  required GroupMembersDao groupMembersDao,
  required GroupOpsLogDao groupOpsLogDao,
  required AppDatabase db,
  required String myPubkeyHex,
  required bool showNotification,
}) async {
  // 1. Sig verify.
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

  // 2. Contacts trust gate.
  final repo = ContactsRepository(db);
  final allContacts = await repo.loadAll();
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

  // 4. Self must be in members.
  if (!inv.members.contains(myPubkeyHex)) {
    _log('[Group] self_not_in_invite chat=${_short(inv.chatId)}');
    return;
  }

  // 5. Idempotency.
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
  final body = '${_short(inv.creator)} created the group';
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

  // Spec §8.5 — notify on group_invite. Fire AFTER persistence so the tap
  // deep-link finds the chat row.
  if (showNotification) {
    try {
      await _showMessageNotification(
        title: 'New group: ${inv.groupName}',
        body: '${_short(inv.creator)} added you',
        payload: inv.chatId,
      );
    } catch (e, st) {
      _log('show invite notification FAILED: $e\n$st');
    }
  }
}

/// T8.1 — mirror of MessageService._handleMemberAdd (lines 994–1104).
Future<void> _handleMemberAdd({
  required String senderPubkeyHex,
  required MemberAddEnvelope inv,
  required ChatsDao dao,
  required GroupMembersDao groupMembersDao,
  required GroupOpsLogDao groupOpsLogDao,
  required String myPubkeyHex,
}) async {
  final chat = await dao.getChat(inv.chatId);
  if (chat == null) {
    _log('[Group] member_add_unknown_chat chat=${_short(inv.chatId)} '
        'from=${_short(senderPubkeyHex)}');
    return;
  }
  if (chat.kind != 'group') {
    _log('[Group] member_add_wrong_kind chat=${_short(inv.chatId)} '
        'kind=${chat.kind}');
    return;
  }
  if (senderPubkeyHex != chat.creatorPubkeyHex) {
    _log('[Group] member_add_signer_not_creator chat=${_short(inv.chatId)} '
        'from=${_short(senderPubkeyHex)} '
        'creator=${_short(chat.creatorPubkeyHex ?? "")}');
    return;
  }

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

  // opSeq window. Spec §7.9.
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

  await groupMembersDao.insertMember(
    chatId: inv.chatId,
    memberPubkeyHex: inv.target,
    addedByPubkeyHex: chat.creatorPubkeyHex!,
    addedAt: inv.addedAt,
  );
  await dao.bumpLastOpSeq(inv.chatId, inv.opSeq);

  final body = inv.target == myPubkeyHex
      ? '${_short(chat.creatorPubkeyHex!)} added you'
      : '${_short(chat.creatorPubkeyHex!)} added ${_short(inv.target)}';
  final now = DateTime.now();
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
  // No notification per spec §8.5.
}

/// T8.1 — mirror of MessageService._handleMemberRemove (lines 1120–1236).
Future<void> _handleMemberRemove({
  required String senderPubkeyHex,
  required MemberRemoveEnvelope inv,
  required ChatsDao dao,
  required GroupMembersDao groupMembersDao,
  required GroupOpsLogDao groupOpsLogDao,
  required String myPubkeyHex,
}) async {
  final chat = await dao.getChat(inv.chatId);
  if (chat == null) {
    _log('[Group] member_remove_unknown_chat chat=${_short(inv.chatId)} '
        'from=${_short(senderPubkeyHex)}');
    return;
  }
  if (chat.kind != 'group') {
    _log('[Group] member_remove_wrong_kind chat=${_short(inv.chatId)} '
        'kind=${chat.kind}');
    return;
  }
  if (senderPubkeyHex != chat.creatorPubkeyHex) {
    _log('[Group] member_remove_signer_not_creator chat=${_short(inv.chatId)} '
        'from=${_short(senderPubkeyHex)} '
        'creator=${_short(chat.creatorPubkeyHex ?? "")}');
    return;
  }

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

  // Target must be in group_members (active OR already-removed for idempotency).
  final all = await groupMembersDao.allMembers(inv.chatId);
  final targetExists = all.any((m) => m.memberPubkeyHex == inv.target);
  if (!targetExists) {
    _log('[Group] member_remove_unknown_target chat=${_short(inv.chatId)} '
        'target=${_short(inv.target)}');
    return;
  }

  // opSeq window. Spec §7.9.
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

  final body = inv.target == myPubkeyHex
      ? '${_short(chat.creatorPubkeyHex!)} removed you'
      : '${_short(chat.creatorPubkeyHex!)} removed ${_short(inv.target)}';
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
  // No notification per spec §8.5.
}

/// T8.1 — mirror of MessageService._handleMemberLeave (lines 1252–1342).
/// No opSeq window; sig verifies under SIGNER's pubkey (not creator's).
Future<void> _handleMemberLeave({
  required String senderPubkeyHex,
  required MemberLeaveEnvelope inv,
  required ChatsDao dao,
  required GroupMembersDao groupMembersDao,
  required GroupOpsLogDao groupOpsLogDao,
}) async {
  final chat = await dao.getChat(inv.chatId);
  if (chat == null) {
    _log('[Group] member_leave_unknown_chat chat=${_short(inv.chatId)} '
        'from=${_short(senderPubkeyHex)}');
    return;
  }
  if (chat.kind != 'group') {
    _log('[Group] member_leave_wrong_kind chat=${_short(inv.chatId)} '
        'kind=${chat.kind}');
    return;
  }
  final isActive = await groupMembersDao.isActiveMember(
      inv.chatId, senderPubkeyHex);
  if (!isActive) {
    _log('[Group] member_leave_not_active chat=${_short(inv.chatId)} '
        'signer=${_short(senderPubkeyHex)}');
    return;
  }

  final canonicalBody = <String, dynamic>{
    'v': 1, 'type': 'member_leave',
    'chatId': inv.chatId, 'lamport': inv.lamport,
    'leftAt': inv.leftAt.toUtc().toIso8601String(),
  };
  final canonical = canonicalJsonBytes(canonicalBody);
  final sigOk = await SigningService.verify(
    publicKeyHex: senderPubkeyHex,
    message: canonical,
    signature: hexToBytes(inv.sigHex),
  );
  if (!sigOk) {
    _log('[Group] member_leave_sig_fail chat=${_short(inv.chatId)} '
        'signer=${_short(senderPubkeyHex)}');
    await groupOpsLogDao.append(
      id: _uuid.v4(),
      chatId: inv.chatId,
      opSeq: null,
      kind: 'leave',
      targetPubkeyHex: null,
      signerPubkeyHex: senderPubkeyHex,
      signatureHex: inv.sigHex,
      applied: false,
    );
    return;
  }

  final now = DateTime.now();
  await groupMembersDao.markRemoved(
    chatId: inv.chatId,
    memberPubkeyHex: senderPubkeyHex,
    removedAt: inv.leftAt,
  );

  final body = '${_short(senderPubkeyHex)} left';
  final lamport = await dao.observeLamport(inv.chatId, inv.lamport);
  await dao.insertMessage(MessagesCompanion.insert(
    id: _uuid.v4(),
    chatId: inv.chatId,
    senderPubkeyHex: senderPubkeyHex,
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
    signerPubkeyHex: senderPubkeyHex,
    signatureHex: inv.sigHex,
    applied: true,
  );
  _log('member_leave accepted chat=${_short(inv.chatId)} '
      'signer=${_short(senderPubkeyHex)}');
  // No notification per spec §8.5.
}

Future<void> _showMessageNotification({
  required String title,
  required String body,
  required String payload,
}) async {
  // Each isolate gets its own plugin instance. The OS-side channel is shared
  // (created in main isolate at boot), so re-init here is safe + idempotent.
  final plugin = FlutterLocalNotificationsPlugin();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await plugin.initialize(settings: initSettings);

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      NotificationsService.messagesChannelId,
      'Heartbeat messages',
      channelDescription: 'Incoming Heartbeat chat messages',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Use a 31-bit notification id so each notification stays distinct
  // (Android collapses if id is reused). 31-bit because the int field is
  // signed 32-bit Java int.
  final id = DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);
  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
    payload: payload,
  );
}

String _preview(String body) =>
    body.length <= 80 ? body : '${body.substring(0, 77)}...';

String _short(String hex) =>
    hex.length >= 16
        ? '${hex.substring(0, 6)}…${hex.substring(hex.length - 6)}'
        : hex;

void _log(String msg) {
  // ignore: avoid_print
  print('[BG] $msg');
}
