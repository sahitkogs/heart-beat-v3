import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../data/app_database.dart';

/// Stream of messages for a single chat, ordered by Lamport (DAO ordering).
final chatThreadProvider = StreamProvider.family<List<Message>, String>(
  (ref, peerPubkeyHex) =>
      ref.watch(chatsDaoProvider).watchMessages(peerPubkeyHex),
);
