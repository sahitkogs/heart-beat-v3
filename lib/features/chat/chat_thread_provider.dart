import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../data/app_database.dart';

/// Stream of messages for a single chat, ordered by Lamport (DAO ordering).
final chatThreadProvider = StreamProvider.family<List<Message>, String>(
  (ref, chatId) => ref.watch(chatsDaoProvider).watchMessages(chatId),
);

/// Stream of chat metadata for a single chat — rebuilds UI if e.g. leftAt
/// changes when an inbound member_remove is processed.
final chatProvider = StreamProvider.family<Chat?, String>(
  (ref, chatId) => ref.watch(chatsDaoProvider).watchChat(chatId),
);
