import 'package:drift/drift.dart';

import 'app_database.dart';

part 'chats_dao.g.dart';

@DriftAccessor(tables: [Chats, Messages, LamportSeq])
class ChatsDao extends DatabaseAccessor<AppDatabase> with _$ChatsDaoMixin {
  ChatsDao(super.db);

  Stream<List<Chat>> watchChats() =>
      (select(chats)..orderBy([(c) => OrderingTerm.desc(c.lastMessageAt)])).watch();

  Future<void> ensureChat(String peerPubkeyHex) async {
    await into(chats).insert(
      ChatsCompanion.insert(
        peerPubkeyHex: peerPubkeyHex,
        createdAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
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
    await (update(chats)..where((t) => t.peerPubkeyHex.equals(chatId))).write(
      ChatsCompanion(
        lastMessageAt: Value(at),
        lastMessagePreview: Value(preview),
      ),
    );
  }

  Future<Chat?> getChat(String peerPubkeyHex) =>
      (select(chats)..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
          .getSingleOrNull();

  Future<void> markBundleSent(String peerPubkeyHex, {DateTime? at}) async {
    await (update(chats)..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
        .write(ChatsCompanion(bundleSentAt: Value(at ?? DateTime.now())));
  }

  Future<void> markPeerBundleReceived(String peerPubkeyHex, {DateTime? at}) async {
    await (update(chats)..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
        .write(ChatsCompanion(peerBundleReceivedAt: Value(at ?? DateTime.now())));
  }

  Future<void> clearBundleSent(String peerPubkeyHex) async {
    await (update(chats)..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
        .write(const ChatsCompanion(bundleSentAt: Value(null)));
  }
}
