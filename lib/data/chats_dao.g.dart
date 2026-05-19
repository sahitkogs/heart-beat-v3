// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chats_dao.dart';

// ignore_for_file: type=lint
mixin _$ChatsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChatsTable get chats => attachedDatabase.chats;
  $MessagesTable get messages => attachedDatabase.messages;
  $LamportSeqTable get lamportSeq => attachedDatabase.lamportSeq;
  ChatsDaoManager get managers => ChatsDaoManager(this);
}

class ChatsDaoManager {
  final _$ChatsDaoMixin _db;
  ChatsDaoManager(this._db);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db.attachedDatabase, _db.chats);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$LamportSeqTableTableManager get lamportSeq =>
      $$LamportSeqTableTableManager(_db.attachedDatabase, _db.lamportSeq);
}
