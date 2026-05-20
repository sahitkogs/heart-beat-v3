import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fcm_service.dart';
import '../../services/phonebook_client.dart';
import '../identity/identity_provider.dart';

/// HTTP base URL of the relay server's REST endpoints (phonebook + wake).
/// Companion to the WS URL declared in `message_service_provider.dart`.
const String relayHttpBaseUrl = 'http://34.42.231.29:8080';

final phonebookClientProvider = Provider<PhonebookClient>((ref) {
  final signing = ref.watch(signingServiceProvider);
  final client = PhonebookClient(
    baseUri: Uri.parse(relayHttpBaseUrl),
    signing: signing,
  );
  return client;
});

final fcmServiceProvider = Provider<FcmService>((ref) {
  final svc = FcmService(phonebook: ref.watch(phonebookClientProvider));
  ref.onDispose(() => svc.dispose());
  return svc;
});

/// Side-effect provider: awaits identity to load (so SigningService has a
/// key) and then kicks off `FcmService.init()` to fetch the FCM token and
/// register the phonebook entry. Watched (fire-and-forget) by HomeScreen
/// after the first frame.
final fcmRegistrationProvider = FutureProvider<void>((ref) async {
  await ref.watch(identityProvider.future);
  final fcm = ref.watch(fcmServiceProvider);
  await fcm.init();
});
