import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../chat/message_service.dart';
import '../../relay/relay_client.dart';
import '../../services/crypto_service.dart';
import '../../services/libsignal_crypto_service.dart';
import '../../services/wake_client.dart';
import '../contacts/contacts_provider.dart';
import '../identity/identity_provider.dart';
import '../notifications/fcm_provider.dart';

const String relayWsUrl = 'ws://34.42.231.29:8080/v1/signal';

final cryptoServiceProvider = FutureProvider<CryptoService>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final svc = LibsignalCryptoService(db);
  await svc.initialize();
  return svc;
});

final relayClientProvider = FutureProvider<RelayClient>((ref) async {
  final signing = ref.watch(signingServiceProvider);
  final client = RelayClient(
    relayWsUrl: Uri.parse(relayWsUrl),
    signing: signing,
  );
  await client.connect();
  ref.onDispose(() => client.dispose());
  return client;
});

final wakeClientProvider = Provider<WakeClient>((ref) {
  final signing = ref.watch(signingServiceProvider);
  final client = WakeClient(
    baseUri: Uri.parse(relayHttpBaseUrl),
    signing: signing,
  );
  ref.onDispose(() => client.dispose());
  return client;
});

final messageServiceProvider = FutureProvider<MessageService>((ref) async {
  final crypto = await ref.watch(cryptoServiceProvider.future);
  final relay = await ref.watch(relayClientProvider.future);
  final dao = ref.watch(chatsDaoProvider);
  final peerBundleDao = ref.watch(peerBundleStateDaoProvider);
  final identity = await ref.watch(identityProvider.future);
  final wake = ref.watch(wakeClientProvider);
  final groupMembersDao = ref.watch(groupMembersDaoProvider);
  final groupOpsLogDao = ref.watch(groupOpsLogDaoProvider);
  final signing = ref.watch(signingServiceProvider);
  final contactsRepository = ref.watch(contactsRepositoryProvider);
  final profileDao = ref.watch(profileDaoProvider);
  final svc = MessageService(
    crypto: crypto,
    relay: relay,
    dao: dao,
    peerBundleDao: peerBundleDao,
    myPubkeyHex: identity.publicKeyHex,
    wake: wake,
    groupMembersDao: groupMembersDao,
    groupOpsLogDao: groupOpsLogDao,
    signing: signing,
    contactsRepository: contactsRepository,
    profileDao: profileDao,
  );
  ref.onDispose(() => svc.dispose());
  return svc;
});
