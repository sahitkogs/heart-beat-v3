import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../data/peer_bundle_state_dao.dart';
import '../features/contacts/contacts_provider.dart';

final chatsDaoProvider = Provider<ChatsDao>(
  (ref) => ChatsDao(ref.watch(appDatabaseProvider)),
);

final peerBundleStateDaoProvider = Provider<PeerBundleStateDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PeerBundleStateDao(db);
});

final chatsStreamProvider = StreamProvider<List<Chat>>(
  (ref) => ref.watch(chatsDaoProvider).watchChats(),
);
