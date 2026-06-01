import 'package:drift/drift.dart';

import 'app_database.dart';

part 'chats_dao.g.dart';

@DriftAccessor(tables: [Chats, Messages, LamportSeq])
class ChatsDao extends DatabaseAccessor<AppDatabase> with _$ChatsDaoMixin {
  ChatsDao(super.db);

  Stream<List<Chat>> watchChats() =>
      (select(chats)..orderBy([(c) => OrderingTerm.desc(c.lastMessageAt)])).watch();

  Future<void> ensureDirectChat(String peerPubkeyHex) async {
    await into(chats).insert(
      ChatsCompanion.insert(
        chatId: peerPubkeyHex,
        kind: const Value('direct'),
        createdAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> insertGroupChat({
    required String chatId,
    required String groupName,
    required String creatorPubkeyHex,
    required DateTime createdAt,
    required int initialOpSeq,
  }) async {
    await into(chats).insert(
      ChatsCompanion.insert(
        chatId: chatId,
        kind: const Value('group'),
        groupName: Value(groupName),
        creatorPubkeyHex: Value(creatorPubkeyHex),
        createdAt: createdAt,
        lastOpSeq: Value(initialOpSeq),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> bumpLastOpSeq(String chatId, int newSeq) async {
    await (update(chats)..where((t) => t.chatId.equals(chatId)))
        .write(ChatsCompanion(lastOpSeq: Value(newSeq)));
  }

  Future<void> setLeftAt(String chatId, DateTime t) async {
    await (update(chats)..where((t2) => t2.chatId.equals(chatId)))
        .write(ChatsCompanion(leftAt: Value(t)));
  }

  Future<int> bumpLamport(String chatId) async {
    return transaction(() async {
      final existing = await (select(lamportSeq)..where((t) => t.chatId.equals(chatId)))
          .getSingleOrNull();
      final next = (existing?.value ?? 0) + 1;
      await into(lamportSeq).insertOnConflictUpdate(
        LamportSeqCompanion.insert(chatId: chatId, value: next),
      );
      return next;
    });
  }

  Future<int> observeLamport(String chatId, int incoming) async {
    return transaction(() async {
      final existing = await (select(lamportSeq)..where((t) => t.chatId.equals(chatId)))
          .getSingleOrNull();
      final currentValue = existing?.value ?? 0;
      final next = currentValue < incoming ? incoming : currentValue;
      await into(lamportSeq).insertOnConflictUpdate(
        LamportSeqCompanion.insert(chatId: chatId, value: next),
      );
      return next;
    });
  }

  Future<void> insertMessage(MessagesCompanion msg) =>
      into(messages).insert(msg, mode: InsertMode.insertOrIgnore);

  Stream<List<Message>> watchMessages(String chatId) =>
      (select(messages)
            ..where((m) => m.chatId.equals(chatId))
            ..orderBy([(m) => OrderingTerm.asc(m.lamport)]))
          .watch();

  Future<void> updateLastMessage(String chatId, String preview, DateTime at) async {
    await (update(chats)..where((t) => t.chatId.equals(chatId))).write(
      ChatsCompanion(
        lastMessageAt: Value(at),
        lastMessagePreview: Value(preview),
      ),
    );
  }

  Future<Chat?> getChat(String chatId) =>
      (select(chats)..where((t) => t.chatId.equals(chatId)))
          .getSingleOrNull();

  Stream<Chat?> watchChat(String chatId) =>
      (select(chats)..where((t) => t.chatId.equals(chatId)))
          .watchSingleOrNull();

  /// Atomically drop a direct chat: messages, lamport seq, and the chat row.
  /// Guarded to `kind == 'direct'` so a caller passing a group chatId by
  /// mistake can't accidentally nuke a group row (group teardown is its own
  /// path — the protocol uses MemberRemove / Leave instead).
  Future<void> deleteDirectChat(String chatId) {
    return transaction(() async {
      await (delete(messages)..where((m) => m.chatId.equals(chatId))).go();
      await (delete(lamportSeq)..where((l) => l.chatId.equals(chatId))).go();
      await (delete(chats)
            ..where((c) => c.chatId.equals(chatId) & c.kind.equals('direct')))
          .go();
    });
  }

  /// Read a single message row by primary key. Used by `MessageService` to
  /// dedup inbound text envelopes by msgId before insert.
  Future<Message?> findMessageById(String msgId) =>
      (select(messages)..where((m) => m.id.equals(msgId))).getSingleOrNull();

  /// Move `delivery_state` forward iff the new ordinal is strictly greater
  /// than the existing one. Receipts are best-effort and can arrive in any
  /// order (e.g. read before delivered after a retransmit); this guards the
  /// monotonic invariant. `failed` is a terminal side-state — callers should
  /// not invoke this with `failed`; use `updateDeliveryState` instead.
  Future<void> advanceDeliveryStateIfHigher(
      String msgId, DeliveryState newState) async {
    final current = await findMessageById(msgId);
    if (current == null) return;
    if (current.deliveryState.index >= newState.index) return;
    await (update(messages)..where((m) => m.id.equals(msgId)))
        .write(MessagesCompanion(deliveryState: Value(newState)));
  }

  /// Force-set `delivery_state`. Used by the retransmitter to flip a row to
  /// `failed` after the max attempt / 24h expiry. Skips the monotonic guard
  /// because `failed` is terminal and intentionally a "downgrade" from `sent`.
  Future<void> updateDeliveryState(String msgId, DeliveryState state) async {
    await (update(messages)..where((m) => m.id.equals(msgId)))
        .write(MessagesCompanion(deliveryState: Value(state)));
  }

  /// Stream a single message's `delivery_state`. The chat UI subscribes per
  /// outbound bubble so tick changes re-render without a full chat refresh.
  Stream<DeliveryState> watchDeliveryState(String msgId) =>
      (select(messages)..where((m) => m.id.equals(msgId)))
          .watchSingleOrNull()
          .map((row) => row?.deliveryState ?? DeliveryState.sent);

  /// Returns ids of inbound (non-self) messages from [peerPubkeyHex] that
  /// have not been locally marked read yet. Used by ChatThreadScreen to
  /// batch a `read` receipt when the thread becomes visible.
  Future<List<String>> unreadInboundMsgIds(String peerPubkeyHex) async {
    final rows = await (select(messages)
          ..where((m) =>
              m.senderPubkeyHex.equals(peerPubkeyHex) &
              m.chatId.equals(peerPubkeyHex) & // direct chats only
              m.readAt.isNull()))
        .get();
    return rows.map((r) => r.id).toList();
  }

  /// Records-integrity audit (D1): count outbound messages still in
  /// `delivery_state == sent` (enum index 0 — never advanced to delivered/
  /// read/failed) that have NO corresponding `outbox` row. A live outbox row
  /// means the message is still being retried (= not lost); its absence with a
  /// stuck `sent` state means it was sent into the void and never confirmed.
  ///
  /// Gated on `known_ticks = 1`: `delivery_state` DEFAULTS to 0 (sent), so
  /// without this gate EVERY inbound/received row (which we never sent and
  /// never advances the column) plus every legacy pre-tick outbound row would
  /// be miscounted as orphaned. `known_ticks` is true ONLY for genuine
  /// outbound rows that went through the Phase 10.4.3b delivery-tracking path,
  /// which is exactly the population this audit is about.
  ///
  /// Read-only; cross-table `NOT IN` against the outbox table, matching the
  /// raw-SQL style used elsewhere for cross-table reads.
  Future<int> countOrphanedSent() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM messages '
      'WHERE known_ticks = 1 '
      'AND delivery_state = ${DeliveryState.sent.index} '
      'AND id NOT IN (SELECT msg_id FROM outbox)',
      readsFrom: {messages, db.outbox},
    ).getSingle();
    return row.read<int>('c');
  }

  /// Mark a batch of messages locally read (sets `read_at = now`). Local-only;
  /// the read receipt back to the peer is sent separately by the debouncer.
  Future<void> markRead(List<String> msgIds) async {
    if (msgIds.isEmpty) return;
    final now = DateTime.now();
    await (update(messages)..where((m) => m.id.isIn(msgIds)))
        .write(MessagesCompanion(readAt: Value(now)));
  }
}
