import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notifications_service.dart';
import '../chat/chat_list_screen.dart';
import '../contacts/contacts_screen.dart';
import '../identity/identity_screen.dart';
import '../notifications/fcm_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger the POST_NOTIFICATIONS permission prompt after the first frame
    // so the OS dialog overlays a rendered UI, not a blank pre-runApp screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationsService.instance.requestPermission();
      // Fire-and-forget: gated on identityProvider, so this resolves once
      // the user's keypair exists; failure is logged but never blocks UI.
      ref.read(fcmRegistrationProvider.future).catchError((Object e) {
        // ignore: avoid_print
        print('[HomeScreen] fcm registration failed: $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heartbeat')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IdentityScreen()),
                ),
                icon: const Icon(Icons.qr_code),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('My identity'),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactsScreen()),
                ),
                icon: const Icon(Icons.people),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Contacts'),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                ),
                icon: const Icon(Icons.chat_bubble),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Chats'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
