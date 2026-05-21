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
}
