import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/presence_client.dart';
import '../chat/message_service_provider.dart'; // messageServiceProvider
import '../contacts/contacts_provider.dart'; // contactsListProvider
import '../identity/identity_provider.dart'; // signingServiceProvider
import '../notifications/fcm_provider.dart'; // relayHttpBaseUrl

/// Pure helper (unit-tested): pubkeys that became online since the last poll.
Set<String> newlyOnline(
    Map<String, PresenceInfo> prev, Map<String, PresenceInfo> next) {
  final ups = <String>{};
  next.forEach((pk, info) {
    if (info.online && (prev[pk]?.online ?? false) == false) ups.add(pk);
  });
  return ups;
}

/// Ephemeral presence map keyed by pubkey hex. Never persisted.
class PresenceNotifier extends StateNotifier<Map<String, PresenceInfo>> {
  PresenceNotifier(this._ref) : super(const {});

  final Ref _ref;
  Timer? _timer;
  static const pollInterval = Duration(seconds: 25);

  /// Foreground entry: poll immediately, then on an interval.
  void startPolling() {
    _timer ??= Timer.periodic(pollInterval, (_) => pollOnce());
    pollOnce();
  }

  /// Background entry: stop the data/battery drain.
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> pollOnce() async {
    final contacts = await _ref.read(contactsListProvider.future);
    if (contacts.isEmpty) return;
    final pubkeys = contacts.map((c) => c.pubkeyHex).toList();

    final client = _ref.read(presenceClientProvider);
    final fresh = await client.fetchPresence(pubkeys);
    if (fresh.isEmpty) return; // network error → keep last-known

    final ups = newlyOnline(state, fresh);
    state = {...state, ...fresh};

    if (ups.isNotEmpty) {
      final ms = await _ref.read(messageServiceProvider.future);
      for (final pk in ups) {
        unawaited(ms.flushPeerOnReachable(pk));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Built exactly like `phonebookClientProvider`/`wakeClientProvider` in
/// fcm_provider.dart / message_service_provider.dart: same relay HTTP base
/// URL constant + same SigningService source. Identical signing contract to
/// PhonebookClient (Ed25519 over `"rfc3339-ts\nbody"`), so reusing both is
/// what keeps the signed `POST /v1/presence` from 401-ing.
final presenceClientProvider = Provider<PresenceClient>((ref) {
  final signing = ref.watch(signingServiceProvider);
  final client = PresenceClient(
    baseUri: Uri.parse(relayHttpBaseUrl),
    signing: signing,
  );
  ref.onDispose(() => client.dispose());
  return client;
});

final presenceProvider =
    StateNotifierProvider<PresenceNotifier, Map<String, PresenceInfo>>(
        (ref) => PresenceNotifier(ref));
